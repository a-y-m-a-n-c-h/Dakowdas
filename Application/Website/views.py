#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from flask import Blueprint , request, render_template, flash, redirect, url_for
from flask_login import login_required
views = Blueprint('views', __name__)
from main import conn
from auth import current_user
from datetime import datetime, timedelta
@views.route('/',methods = ['GET']) # decorator
@login_required
def home(): 
    cur = conn.cursor()
    select_query = """
                    SELECT "announcementID", username, language, content, "timestamp"
                            FROM public."Announcement" a
                            order by a."timestamp" DESC
                   """
    cur.execute(select_query)
    announcements = cur.fetchall()
    return render_template('index.html', announcements = announcements, now = datetime.now())

@views.route('/contests', methods=["GET"])
@login_required
def contests():
    cur = conn.cursor()
    contests_query = """SELECT
        c.name,
        c."divsion",
        c."startTimestamp",
        c.length,
        (
            SELECT COUNT(s2.verdict)
            FROM public."Contest" c1
            JOIN public."ProgrammingProblem" p ON p."roundNumber" = c1."roundNumber"
            JOIN public."Submits" s ON s."problemNumber" = p."problemID"
            JOIN public."Submission" s2 ON s2."submissionID" = s."submissionID"
            WHERE
                c1."roundNumber" = c."roundNumber" AND
                s."username" = %s AND
                s2."verdict" = 'Accepted'
            GROUP BY c1."roundNumber"
        ) AS problemsSolved
    FROM
        public."Contest" c
    WHERE now() > c."startTimestamp" + c.length
    ORDER BY c."startTimestamp" DESC;
    """

    cur.execute(contests_query, (current_user.username,))
    pastContests = cur.fetchall()
    print(pastContests)
    return render_template("contests.html", pastContests=pastContests)

@views.route('/battles', methods=["GET"])
@login_required
def battles():
    cur = conn.cursor()
    battle_query = """
    SELECT u1."battleID", u1."username", u2."username", u1."isWinner", u3."startTimestamp", u3."endTimestamp"
    FROM public."Joins" u1
    JOIN public."Joins" u2 ON u1."battleID" = u2."battleID"
    JOIN public."Battle" u3 ON u1."battleID" = u3."battleID"
    WHERE u1."username" = %s AND u1."username" != u2."username"
    order by u3."startTimestamp" desc
    """

    cur.execute(battle_query, (current_user.username,))
    battles = cur.fetchall()
    print(battles)
    return render_template("battles.html", battles = battles)

@views.route('/problems', methods=["GET"])
@login_required
def problems():
    cur = conn.cursor()
    username = current_user.username 
    sql_query = """
    SELECT
    p."problemID",
    p."roundNumber",
    p."difficultyLevel",
    p.title,
    EXISTS (
        SELECT 1
        FROM public."Submits" s
        JOIN public."Submission" s2 ON s."submissionID" = s2."submissionID"
        WHERE
            s2.verdict = 'Accepted'
            AND s.username = %s
            AND p."problemID" = s."problemNumber"
    ) AS "isAccepted",
    COALESCE(
        (
            SELECT COUNT(s3."problemNumber")
            FROM public."Submits" s3
            JOIN public."Submission" s4 ON s3."submissionID" = s4."submissionID"
            WHERE p."problemID" = s3."problemNumber" AND s4."verdict" = 'Accepted'
            GROUP BY s3."problemNumber"
        ),
        0
    ) AS "acceptedCount"
FROM public."ProgrammingProblem" p
JOIN public."Contest" c ON p."roundNumber" = c."roundNumber"
WHERE 
    c."startTimestamp" + c."length" < NOW()
ORDER BY p."roundNumber" DESC, p."difficultyLevel" DESC;

    """
    cur.execute(sql_query,(username,))
    tags = {} # each problemID will lead to a list of tags for the problem
    
    problems = cur.fetchall()
    for problem in problems:
        tags[problem[0]] = []
        problem_id = problem[0]
        sql_query = """
        SELECT tag
        FROM public."Tag" t
        WHERE t."problemID" = %s;
        """
        cur.execute(sql_query, (problem_id,))
        tagsTemp = cur.fetchall()
        for tag in tagsTemp:
            tags[problem[0]].append(tag[0])
    
    return render_template("problems.html",problems = problems, tags = tags)

@views.route('/profile', methods=["GET"])
@login_required
def profile():
    cur = conn.cursor()
    username = current_user.username
    query = "SELECT \"friend2Username\" FROM public.\"Befriends\" WHERE \"friend1Username\" = "
    query += "'"
    query += username
    query += "'"
    cur.execute(query)
    friends = cur.fetchall()
    nof = len(friends)
    query = """
        SELECT s."problemNumber"
        FROM public."Submits" s
        JOIN public."Submission" s2 ON s2."submissionID" = s."submissionID"
        WHERE username = %s AND verdict = 'Accepted'
        GROUP BY s."problemNumber"
    """
    
    cur.execute(query, (username,))
    problems = cur.fetchall()
    nOfProblems = len(problems)
    query = "SELECT rating FROM public.\"Contestant\" WHERE \"contestantUsername\" = %s"
    cur.execute(query, (username,))
    rating = cur.fetchone()
    if rating != None:
        rating = rating[0]
    else:
        rating = 'NA'
    
    return render_template("profile.html",nOfProblems=nOfProblems,nof=nof,Rating = rating)

@views.route('/contact', methods=["GET"])
def contact():
    return render_template("contact.html")
@views.route('/friends', methods=['GET'])
@login_required
def friends():
    cur = conn.cursor()
    username = current_user.username
    query = "SELECT \"friend2Username\" FROM public.\"Befriends\" WHERE \"friend1Username\" = "
    query += "'"
    query += username
    query += "'"
    cur.execute(query)
    friends = cur.fetchall()
    return render_template("friends.html",friends=friends)
@views.route('/problemsSolved', methods=['GET'])
@login_required
def ps():
    cur = conn.cursor()
    username = current_user.username
    query = """
        SELECT s."problemNumber"
        FROM public."Submits" s
        JOIN public."Submission" s2 ON s2."submissionID" = s."submissionID"
        WHERE username = %s AND verdict = 'Accepted'
        GROUP BY s."problemNumber"
    """
    
    cur.execute(query, (username,))
    problems = cur.fetchall()
    print(problems)
    return render_template("problemsSolved.html",problems_solved=problems)
@views.route('/problems/<path:problemTitle>')
def problemDesc(problemTitle):
    cur = conn.cursor()
    title_to_search = problemTitle  
    sql_query = """
    SELECT "difficultyLevel", title, description, "timeLimit", "memoryLimit"
    FROM public."ProgrammingProblem" p
    WHERE p."title" = %s;
    """
    cur.execute(sql_query, (title_to_search,))
    result = cur.fetchone()
    print(result)
    return render_template("problemDesc.html",result=result)
@views.route('/submissions/<path:problemTitle>/<int:problemNumber>')
def problemSubmissions(problemTitle,problemNumber):
    cur = conn.cursor()
    sql_query = """
    SELECT s.username, s."submissionID", s2."programmingLanguage", s2."verdict", s2."timestamp" 
    FROM public."Submits" s 
    JOIN public."Submission" s2 ON s."submissionID" = s2."submissionID"
    WHERE s2."verdict" = 'Accepted' AND s."problemNumber" = %s;
    """
    cur.execute(sql_query, (problemNumber,))
    result = cur.fetchall()
    return render_template("problemSubmissions.html",result = result)
@views.route('/userSearch', methods=['POST'])
def userSearch():
    if request.method == 'POST':
        cur = conn.cursor()
        userSearched = request.form.get('user')
        
        # Use ILIKE for case-insensitive search
        sql_query = """
            SELECT username
            FROM public."User" u
            WHERE username ILIKE %s
        """
        # Use a tuple to pass the parameter to execute
        cur.execute(sql_query, ('%' + userSearched + '%',))
        
        users = cur.fetchall()
        return render_template("userSearch.html", users=users)
@views.route('/userSearch/profile/<path:user>',methods = ['GET','POST'])
def profileUser(user):
    cur = conn.cursor()
    if request.method == 'POST':
        button = request.form.get('button')
        print(button)
        if button != "remove":
            insert_query = """INSERT INTO public."Befriends"(
	                         "friend1Username", "friend2Username", "timestamp")
	                          VALUES (%s, %s, %s);"""
            cur.execute(insert_query,(current_user.username,user,datetime.now()))
            conn.commit()
        else:
            delete_query = """DELETE FROM public."Befriends" b
	                          WHERE b."friend1Username" = %s and b."friend2Username" = %s"""
            cur.execute(delete_query,(current_user.username,user))
    
    
    username = user
    query = "SELECT \"friend2Username\" FROM public.\"Befriends\" WHERE \"friend1Username\" = "
    query += "'"
    query += username
    query += "'"
    cur.execute(query)
    friends = cur.fetchall()
    nof = len(friends)
    query = """
        SELECT s."problemNumber"
        FROM public."Submits" s
        JOIN public."Submission" s2 ON s2."submissionID" = s."submissionID"
        WHERE username = %s AND verdict = 'Accepted'
        GROUP BY s."problemNumber"
    """
    
    cur.execute(query, (username,))
    problems = cur.fetchall()
    nOfProblems = len(problems)
    query = "SELECT rating FROM public.\"Contestant\" WHERE \"contestantUsername\" = %s"
    cur.execute(query, (username,))
    rating = cur.fetchone()
    if rating != None:
        rating = rating[0]
    else:
        rating = 'NA'
    query = """SELECT username, email, passwod, "firstName", "lastName", country, "registrationDate"
	FROM public."User" u
	where u."username" = %s"""
    cur.execute(query,(username,))
    userInfo = cur.fetchone()
    sql_query = """
    SELECT "timestamp"
    FROM public."Befriends" b
    WHERE b."friend1Username" = %s AND b."friend2Username" = %s
    """
    cur.execute(sql_query, (current_user.username, username))
    timeStampFriend = cur.fetchone()
    if current_user.username == username :
        return render_template("userProfile.html",nOfProblems=nOfProblems,nof=nof,Rating = rating,userInfo = userInfo, isFriend = -1)
    if timeStampFriend == None:
        isFriend = False ;
        return render_template("userProfile.html",nOfProblems=nOfProblems,nof=nof,Rating = rating,userInfo = userInfo,isFriend=isFriend,timeStampFriend=timeStampFriend)
    else:
        timeStampFriend = timeStampFriend[0]
        isFriend = True
        return render_template("userProfile.html",nOfProblems=nOfProblems,nof=nof,Rating = rating,userInfo = userInfo, isFriend=isFriend,timeStampFriend=timeStampFriend)
@views.route('/messages')
def messages():
    cur = conn.cursor()
    messages_query = """SELECT "senderUsername", content, "timestamp"
                	    FROM public."Messages" m 
	                    where m."receiverUsername" = %s
	                    order by m."timestamp" desc"""
    cur.execute(messages_query,(current_user.username,))
    messages = cur.fetchall()
    return render_template("messages.html",messages = messages)
@views.route('/userSearch/profile/messageUser/<path:user>',methods = ['GET','POST'])
def messageUser(user):
    if request.method == 'POST':
        cur = conn.cursor()
        message = request.form.get("message")
        insert_query = """INSERT INTO public."Messages"(
                          "senderUsername", "receiverUsername", content, "timestamp")
    	                   VALUES (%s, %s, %s, %s);"""
        cur.execute(insert_query,(current_user.username,user,message,datetime.now()))
        conn.commit()
        flash("Message Successfuly Sent",category = "Success")
        return redirect(url_for('views.profileUser', user=user))
    
    return render_template('messageUser.html',user=user)
@views.route("/createContest", methods=['GET', 'POST'])
def create_contest():
    if request.method == 'POST':
        cur = conn.cursor()
        # Retrieve contest details
        contest_name = request.form.get('contestName')
        division = request.form.get('division')
        contest_length = request.form.get('contestLength')
        contest_description = request.form.get('contestDescription')
        contest_start_date_str = request.form.get('contestStartDate')
        contest_start_date = datetime.strptime(contest_start_date_str, '%Y-%m-%dT%H:%M')
        # Retrieve programming problems details
        problem_titles = request.form.getlist('problemTitle[]')
        difficulty_levels = request.form.getlist('difficultyLevel[]')
        time_limits = request.form.getlist('timeLimit[]')
        memory_limits = request.form.getlist('memoryLimit[]')
        problem_descriptions = request.form.getlist('problemDescription[]')

        # Process the form data as needed
        # For example, you can save the data to the database
        insert_contest = """INSERT INTO public."Contest"(
	                        name, divsion, "startTimestamp", length, description)
	                        VALUES (%s,%s,%s,%s,%s)
                            RETURNING "roundNumber" """
        contest_length = timedelta(minutes=int(contest_length))
        division = int(division)
        cur.execute(insert_contest,(contest_name,division,contest_start_date,contest_length,contest_description))
        round_number = cur.fetchone()[0]
        for i in range(len(problem_titles)):
            insert_problem = """INSERT INTO public."ProgrammingProblem"(
	                         "difficultyLevel", title, description, "timeLimit", "memoryLimit", "roundNumber")
	                         VALUES (%s, %s, %s, %s, %s, %s);"""
            cur.execute(insert_problem,(difficulty_levels[i],problem_titles[i],problem_descriptions[i],time_limits[i],memory_limits[i],round_number))
        
        return render_template("createAnnouncement.html")

    return render_template("createContest.html")
@views.route('/createAnnouncement', methods=['GET', 'POST'])
@login_required  # Ensure the user is logged in
def create_announcement():
    if request.method == 'POST':
        cur = conn.cursor()
        announcement_content = request.form.get('announcementContent')
        insert_announcement = """INSERT INTO public."Announcement"(
	                          username, language, content, "timestamp")
	                           VALUES (%s, %s, %s, %s);"""
        cur.execute(insert_announcement,(current_user.username,'English',announcement_content,datetime.now()))
        conn.commit()
        flash('Announcement created successfully!', category='Success')
        return redirect(url_for('views.home'))

    return render_template('createAnnouncement.html')


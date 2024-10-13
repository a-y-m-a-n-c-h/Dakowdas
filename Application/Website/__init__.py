#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from flask import Flask, request, render_template
from flask_login import LoginManager
#from hashlib import sha256
import psycopg2
def create_app():
    app = Flask(__name__)
    app.config['SECRET_KEY'] = 'uhgwuhgw u9ghew9uhg' #Secure s Cookies and Session Data
    from  views import views
    from auth import auth , User
    login_manager = LoginManager()
    login_manager.login_view = 'auth.login'
    login_manager.init_app(app)
    @login_manager.user_loader
    def load_user(username):
        conn = psycopg2.connect(database = 'Dakowdas',   
                user = 'postgres',
                password = 'doudik!12345',
                host = 'localhost',
                port= '5432'     
        )
        cur = conn.cursor()
        query = "SELECT * FROM public.\"User\" u where u.\"username\" = "
        query += "'" + username + "'"
        cur.execute(query)
        temp = cur.fetchone()
        
        if temp:
            user = User(username = username,email=temp[1],first_name=temp[3],last_name = temp[4],country=temp[5],registration_date=temp[6])
            admin_query = """SELECT username
                             FROM public."Admin" a
                          where a."username" = %s"""
            cur.execute(admin_query,(username,))
            isAdmin = cur.fetchone()
            contestCreator_query = """SELECT "creatorUsername"
                                  FROM public."ContestCreator" c
                               where c."creatorUsername" = %s """
            cur.execute(contestCreator_query,(username,))
            isContestCreator = cur.fetchone()
            contestant_query = """SELECT "contestantUsername"
                           FROM public."Contestant" c
                              where c."contestantUsername" = %s"""
            cur.execute(contestant_query,(username,))
            isContestant = cur.fetchone();
            if isAdmin != None :
                admin_query = """SELECT  role, "contributionScore"
	                             FROM public."Admin" a 
	                             where a."username" = %s"""
                cur.execute(admin_query,(username,))
                adminVal = cur.fetchone()
                user.roles["admin"] = adminVal
                
            if isContestCreator != None :
                creator_query = """SELECT "assessmentScore"
	                               FROM public."ContestCreator" c
	                               where c."creatorUsername" = %s"""
                cur.execute(creator_query,(username,))
                creatorVal = cur.fetchone()
                user.roles["contestCreator"] = creatorVal
            if isContestant != None :
                contestant_query = """SELECT rating
	                                  FROM public."Contestant" c
	                                  where c."contestantUsername" = %s"""
                cur.execute(contestant_query,(username,))
                contestantVal = cur.fetchone()
                user.roles["contestant"] = contestantVal
                
            return user
        return None
    app.register_blueprint(views, url_prefix = '/')
    app.register_blueprint(auth, url_prefix = '/')
    return app 
        
    
#!/usr/bin/env python3
# -*- coding: utf-8 -*-


from flask import Blueprint, render_template, request, flash, redirect, url_for
import psycopg2
from hashlib import sha256
from datetime import datetime
from flask_login import login_user, logout_user, login_required, current_user
from flask_login import UserMixin
from main import conn
auth = Blueprint('auth', __name__)
class User(UserMixin):
    def __init__(self,country, first_name, last_name, username, registration_date,email):
        self.id = username
        self.country = country
        self.first_name = first_name
        self.last_name = last_name
        self.username = username
        self.registration_date = registration_date
        self.email = email
        self.roles = {}
@auth.route('/login', methods = ['GET','POST'])
def login():
    if request.method == "POST":
        cur = conn.cursor()
        username = request.form.get("username")
        password = request.form.get("password")
        if username == "":
            flash("Enter a Username",category = "Error")
            return render_template("login.html", boolean = True)
        if password == "":
            flash("Enter a Password",category = "Error")
            return render_template("login.html", boolean = True)
        query = "SELECT passwod FROM public.\"User\" u where u.\"username\" = "
        query += "'" + username + "'"
        cur.execute(query)
        comparePass = cur.fetchall()
        if len(comparePass) != 0:
            comparePass = comparePass[0][0]
            if comparePass == sha256(password.encode('utf-8')).hexdigest():
                
                query = "SELECT * FROM public.\"User\" u where u.\"username\" = "
                query += "'" + username + "'"
                cur.execute(query)
                temp = cur.fetchone()
                user = User(username = username,email=temp[1],first_name=temp[3],last_name = temp[4],country=temp[5],registration_date=temp[6])
                login_user(user)
                ###############################
                ###############################
                flash("login Successful",category = "Success")
                return redirect(url_for('views.home'))
            else:
                flash("Wrong Username and/or Password", category = "Error")
        else:
            flash("Username does not exist", category = "Error")
        
    return render_template("login.html", user = current_user)
@auth.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('auth.login'))
@auth.route('/sign-up', methods = ['GET','POST'])
def sign_up():
    if request.method == "POST":
        cur = conn.cursor()
        firstName = request.form.get("firstName")
        lastName = request.form.get("lastName")
        email = request.form.get("email")
        country = request.form.get("country")
        username = request.form.get("username")
        password = request.form.get("password")
        if(firstName == ""):
            flash("Enter your first name",category = "Error")
        elif (lastName == ""):
            flash("Enter your last name",category = "Error")
        elif (email == ""):
            flash("Enter your email",category = "Error")
        elif (country == None):
            flash("Enter your country",category = "Error")
        elif (username == ""):
            flash("Enter your username",category = "Error")
        elif (password == ""):
            flash("Enter your password",category = "Error")
        elif len(password) <= 6:
            flash("password must be atleast of length 7",category = "Error")
        else:
            
            query = "SELECT passwod FROM public.\"User\" u where u.\"username\" = "
            query += "'" + username + "'"
            cur.execute(query)
            userExists = cur.fetchall()
            query = "SELECT email FROM public.\"User\" u where u.\"username\" = "
            query += "'" + email + "'"
            cur.execute(query)
            emailExists = cur.fetchall()
            if len(userExists) == 1 :
                flash("username already taken",category = "Error")
            elif len(emailExists) == 1:
                flash("Email already exists",category = "Error")
            else:
                registration_date = datetime.now()
                password = sha256(password.encode('utf-8')).hexdigest()
                sql_query = """
                INSERT INTO public."User"(
                    username, email, passwod, "firstName", "lastName", country, "registrationDate"
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s);
                """
                cur.execute(sql_query,(username,email,password,firstName,lastName,country,registration_date))
                conn.commit()
                flash("SignUp Successful",category = "Success")
                ##########################################################
                
                ##########################################################
                return render_template("login.html")
                
    return render_template("signup.html",user = current_user)




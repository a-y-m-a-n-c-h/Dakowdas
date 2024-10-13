#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# import psycopg2
from flask import Flask, request, render_template
from hashlib import sha256
from __init__ import create_app
import psycopg2
conn = psycopg2.connect(database = 'Dakowdas',   
        user = 'postgres',
        password = 'doudik!12345',
        host = 'localhost',
        port= '5432'     
)
if __name__ == '__main__': # run the app only from main.py file in case file is imported from another py file
    app = create_app()
    app.run()
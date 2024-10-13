# Dakowdas Competitive Programming Website

Welcome to the Dakowdas Competitive Programming Website! This project is a database-driven web application designed to manage competitive programming data, including user profiles, contests, problems, and more. The application is built using Flask, a Python web framework, and utilizes a PostgreSQL database.

## Prerequisites

Before running the application, ensure you have the following installed:

- Python 3
- Flask
- PostgreSQL

You can install Flask using the following command:

```bash
pip install Flask
```

## Setting up the Database

1. Create a PostgreSQL database:

```bash
createdb test2
```

2. Connect to the database and execute the SQL script located in the `database.sql` file to set up the necessary tables and relationships:

```bash
psql -d test2 -f database.sql
```

3. Update the connection details in the `main.py` file:

```python
conn = psycopg2.connect("dbname=test2 user=your_username password=your_password")
```

## Running the Application

1. Run the Flask application:

```bash
python main.py
```

2. Access the application in your web browser at:

```
http://localhost:5000
```

## Contact Information

If you encounter any issues or have questions, please feel free to contact:

- **Dana Kossaybati** (Group Leader): [dak39@mail.aub.edu](mailto:dak39@mail.aub.edu)
- **Mohammad Khaled Charaf**: [mmc51@mail.aub.edu](mailto:mmc51@mail.aub.edu)
- **Mohammad Ayman Charaf**: [mmc50@mail.aub.edu](mailto:mmc50@mail.aub.edu)

# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /usr/src/app

# Install ffmpeg for video processing
RUN apt-get update && \
  apt-get install -y ffmpeg build-essential libpq-dev libssl-dev libffi-dev python3-dev && \
  rm -rf /var/lib/apt/lists/*

# Install Pipenv
RUN pip install pipenv

# Copy the Pipfile and Pipfile.lock into the container
COPY Pipfile Pipfile.lock ./

# Install dependencies from Pipfile.lock
RUN pipenv install --deploy --ignore-pipfile

# Copy the current directory contents into the container at /usr/src/app
COPY . .

# Run main.py when the container launches
CMD ["pipenv", "run", "python", "-u", "main.py"]

# pipenv run python -u main.py
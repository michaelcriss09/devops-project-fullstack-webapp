FROM python:3.10-slim
LABEL "NAME"="Backend"
WORKDIR /app
COPY requirements.txt /app 
RUN pip install --upgrade pip
RUN pip install --no-cache-dir  -r requirements.txt
ADD . /app
EXPOSE 9000
CMD ["python", "main.py"]

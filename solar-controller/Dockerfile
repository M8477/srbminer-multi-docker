FROM python:3.12-slim
RUN pip install --no-cache-dir docker==7.1.0 requests==2.32.3
COPY controller.py /controller.py
CMD ["python", "-u", "/controller.py"]

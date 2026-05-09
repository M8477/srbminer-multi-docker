FROM python:3.12-slim
RUN pip install --no-cache-dir krakenex==2.2.3
COPY sell_bot.py /sell_bot.py
CMD ["python", "-u", "/sell_bot.py"]

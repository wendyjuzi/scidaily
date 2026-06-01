from __future__ import annotations

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import requests

from research_daily.config import PushConfig


def send_email(push_cfg: PushConfig, subject: str, html_body: str) -> None:
    email_cfg = push_cfg.email
    if not email_cfg.enabled:
        return
    if not email_cfg.receivers:
        raise ValueError("email.receivers is empty")

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = email_cfg.sender or email_cfg.username
    msg["To"] = ", ".join(email_cfg.receivers)
    msg.attach(MIMEText(html_body, "html", "utf-8"))

    if email_cfg.use_ssl:
        smtp = smtplib.SMTP_SSL(email_cfg.host, email_cfg.port, timeout=20)
    else:
        smtp = smtplib.SMTP(email_cfg.host, email_cfg.port, timeout=20)
    try:
        if email_cfg.username:
            smtp.login(email_cfg.username, email_cfg.password)
        smtp.sendmail(msg["From"], email_cfg.receivers, msg.as_string())
    finally:
        smtp.quit()


def send_wecom(push_cfg: PushConfig, text: str) -> None:
    wecom_cfg = push_cfg.wecom
    if not wecom_cfg.enabled or not wecom_cfg.webhook:
        return
    payload = {"msgtype": "markdown", "markdown": {"content": text}}
    resp = requests.post(wecom_cfg.webhook, json=payload, timeout=20)
    resp.raise_for_status()


def send_telegram(push_cfg: PushConfig, text: str) -> None:
    tg_cfg = push_cfg.telegram
    if not tg_cfg.enabled or not tg_cfg.bot_token or not tg_cfg.chat_id:
        return
    endpoint = f"https://api.telegram.org/bot{tg_cfg.bot_token}/sendMessage"
    payload = {"chat_id": tg_cfg.chat_id, "text": text}
    resp = requests.post(endpoint, json=payload, timeout=20)
    resp.raise_for_status()


import logging
import smtplib
import ssl
from email.message import EmailMessage

from app.config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()


def send_email(
    to_email: str,
    subject: str,
    text: str,
    html: str | None = None,
    attachments: list[tuple[str, bytes, str]] | None = None,
) -> None:
    if not settings.SMTP_HOST or not settings.SMTP_USER or not settings.SMTP_PASSWORD:
        logger.warning("SMTP is not configured; skipped email to %s", to_email)
        return
    if not settings.SMTP_FROM_EMAIL:
        logger.warning("SMTP_FROM_EMAIL is not configured; skipped email to %s", to_email)
        return

    message = EmailMessage()
    message["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
    message["To"] = to_email
    message["Subject"] = subject
    message.set_content(text)
    if html:
        message.add_alternative(html, subtype="html")
    for filename, content, mime_type in attachments or []:
        maintype, subtype = mime_type.split("/", 1)
        message.add_attachment(
            content,
            maintype=maintype,
            subtype=subtype,
            filename=filename,
        )

    with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=30) as server:
        server.ehlo()
        server.starttls(context=ssl.create_default_context())
        server.ehlo()
        server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
        server.send_message(message)


def send_password_setup_email(to_email: str, setup_url: str) -> None:
    subject = "Set your Sprout Track password"
    text = (
        "Welcome to Sprout Track.\n\n"
        "Your business data has been migrated. Set your password using this link:\n\n"
        f"{setup_url}\n\n"
        "This link expires soon. If you did not request this, ignore this email."
    )
    html = f"""
    <div style="font-family:Arial,sans-serif;line-height:1.6;color:#1f2933">
      <h2>Set your Sprout Track password</h2>
      <p>Your business data has been migrated. Create your password to access your account.</p>
      <p>
        <a href="{setup_url}" style="background:#606c38;color:#ffffff;padding:12px 18px;border-radius:8px;text-decoration:none;display:inline-block">
          Set password
        </a>
      </p>
      <p>If the button does not work, copy this link:</p>
      <p>{setup_url}</p>
      <p>This link expires soon. If you did not request this, ignore this email.</p>
    </div>
    """
    send_email(to_email, subject, text, html)


def send_email_verification_email(to_email: str, verify_url: str) -> None:
    subject = "Verify your Sprout Track account"
    text = (
        "Welcome to Sprout Track.\n\n"
        "Verify your email address to activate your account:\n\n"
        f"{verify_url}\n\n"
        "This link expires soon. If you did not create this account, ignore this email."
    )
    html = f"""
    <div style="font-family:Arial,sans-serif;line-height:1.6;color:#1f2933">
      <h2>Verify your Sprout Track account</h2>
      <p>Thanks for signing up. Verify your email address to activate your account.</p>
      <p>
        <a href="{verify_url}" style="background:#606c38;color:#ffffff;padding:12px 18px;border-radius:8px;text-decoration:none;display:inline-block">
          Verify email
        </a>
      </p>
      <p>If the button does not work, copy this link:</p>
      <p>{verify_url}</p>
      <p>This link expires soon. If you did not create this account, ignore this email.</p>
    </div>
    """
    send_email(to_email, subject, text, html)


def send_welcome_email(to_email: str, full_name: str) -> None:
    subject = "Welcome to Sprout Track"
    name = full_name.strip() or "there"
    text = (
        f"Hi {name},\n\n"
        "Welcome to Sprout Track. Your account is active and ready for invoicing, inventory, expenses, and reports.\n\n"
        "Sign in to start setting up your business workspace."
    )
    html = f"""
    <div style="font-family:Arial,sans-serif;line-height:1.6;color:#1f2933">
      <h2>Welcome to Sprout Track</h2>
      <p>Hi {name},</p>
      <p>Your account is active and ready for invoicing, inventory, expenses, and reports.</p>
      <p>Sign in to start setting up your business workspace.</p>
    </div>
    """
    send_email(to_email, subject, text, html)


def send_invoice_email(
    to_email: str,
    invoice_number: str,
    pdf_bytes: bytes,
    message: str | None = None,
) -> None:
    subject = f"Sprout Track invoice {invoice_number}"
    text = message or f"Please find invoice {invoice_number} attached."
    html = f"""
    <div style="font-family:Arial,sans-serif;line-height:1.6;color:#1f2933">
      <h2>Invoice {invoice_number}</h2>
      <p>{text}</p>
      <p>The PDF document is attached.</p>
    </div>
    """
    send_email(
        to_email,
        subject,
        text,
        html,
        attachments=[(f"{invoice_number}.pdf", pdf_bytes, "application/pdf")],
    )

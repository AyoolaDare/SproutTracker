from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel, EmailStr

from app.config import get_settings
from app.services.email import send_email

router = APIRouter(prefix="/api/diagnostics", tags=["Diagnostics"])
settings = get_settings()


class EmailDiagnosticRequest(BaseModel):
    to_email: EmailStr


@router.post("/email-test")
async def send_diagnostic_email(
    req: EmailDiagnosticRequest,
    x_diagnostic_token: str | None = Header(default=None),
):
    if not settings.DIAGNOSTIC_TOKEN:
        raise HTTPException(status_code=404, detail="Diagnostic email test is disabled")
    if x_diagnostic_token != settings.DIAGNOSTIC_TOKEN:
        raise HTTPException(status_code=403, detail="Invalid diagnostic token")

    send_email(
        req.to_email,
        "Sprout Track Render email delivery test",
        "This email was sent from the live Render backend through Brevo SMTP.",
        """
        <div style="font-family:Arial,sans-serif;line-height:1.6;color:#1f2933">
          <h2>Sprout Track Render email delivery test</h2>
          <p>This email was sent from the live Render backend through Brevo SMTP.</p>
        </div>
        """,
    )
    return {"success": True, "message": "Diagnostic email accepted by SMTP server."}

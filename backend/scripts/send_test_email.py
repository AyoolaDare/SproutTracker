import argparse
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Send a real Sprout Track test email.")
    parser.add_argument("--to", required=True, help="Recipient email address.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    os.environ["ENVIRONMENT"] = "development"

    from app.services.email import send_email

    send_email(
        args.to,
        "Sprout Track email delivery test",
        "Sprout Track email delivery is working.",
        """
        <div style="font-family:Arial,sans-serif;line-height:1.6;color:#1f2933">
          <h2>Sprout Track email delivery is working</h2>
          <p>This message was sent through the same SMTP service used for verification and password reset emails.</p>
        </div>
        """,
    )
    print(f"sent_test_email={args.to}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

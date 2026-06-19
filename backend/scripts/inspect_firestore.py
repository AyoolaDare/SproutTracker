import argparse
import json
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials, firestore


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Inspect Firestore collections without printing document data.")
    parser.add_argument("--service-account", required=True)
    parser.add_argument("--database", default=None, help="Firestore database ID. Defaults to Firebase default database.")
    parser.add_argument("--sample", type=int, default=5)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    service_account = Path(args.service_account).resolve()
    info = json.loads(service_account.read_text(encoding="utf-8"))
    print(f"service_account_project_id={info.get('project_id')}")
    print(f"service_account_client_email={info.get('client_email')}")
    print(f"database={args.database or '(default)'}")

    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(str(service_account)))

    db = firestore.client(database_id=args.database) if args.database else firestore.client()
    collections = list(db.collections())
    print(f"top_level_collections={len(collections)}")
    for collection_ref in collections:
        print(f"collection={collection_ref.id}")
        docs = list(collection_ref.limit(args.sample).stream())
        print(f"  sample_docs={len(docs)}")
        for doc in docs:
            print(f"  doc_id={doc.id}")
            subcollections = [sub.id for sub in doc.reference.collections()]
            if subcollections:
                print(f"  subcollections={','.join(subcollections)}")

    auth_users = []
    try:
        page = auth.list_users()
        for user in page.iterate_all():
            auth_users.append(user.uid)
            if len(auth_users) >= args.sample:
                break
    except Exception as exc:
        print(f"auth_users_error={type(exc).__name__}: {exc}")

    print(f"sample_auth_users={len(auth_users)}")
    for uid in auth_users:
        user_ref = db.collection("users").document(uid)
        user_snap = user_ref.get()
        print(f"auth_uid={uid} parent_exists={user_snap.exists}")
        subcollections = [sub.id for sub in user_ref.collections()]
        if subcollections:
            print(f"  subcollections={','.join(subcollections)}")
            for sub in subcollections:
                count = len(list(user_ref.collection(sub).limit(args.sample).stream()))
                print(f"  {sub}_sample_docs={count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

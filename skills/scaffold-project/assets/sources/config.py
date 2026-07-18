import os

from dotenv import load_dotenv
import pymongo

load_dotenv()

# Run mode: development | testing | production
#   development — native Flask server, debug on
#   testing     — native Flask server, debug on
#   production  — waitress WSGI server, debug off
APP_ENV = os.environ.get("APP_ENV", "development").lower()
IS_PRODUCTION = APP_ENV == "production"
DEBUG = not IS_PRODUCTION

# The app and its MongoDB are assumed co-located (same host). Set MONGO_URI
# per environment in .env; testing may point at a remote/shared DB.
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
DB_NAME = os.environ.get("DB_NAME", "__DB_NAME__")
SECRET_KEY = os.environ.get("SECRET_KEY", "dev-secret-change-me")
PORT = int(os.environ.get("PORT", 5000))

# Site identity — used for SEO meta tags, canonical URLs, robots/sitemap.
SITE_NAME = os.environ.get("SITE_NAME", "__PROJECT_NAME__")
SITE_URL = os.environ.get("SITE_URL", "http://localhost:5000").rstrip("/")

_client = pymongo.MongoClient(MONGO_URI)
db = _client[DB_NAME]

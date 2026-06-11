FROM python:3.12-slim

# Définition du répertoire de travail
WORKDIR /app

# Empêcher Python d'écrire des fichiers .pyc et forcer la sortie stdout/stderr non-bufferisée
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Installer les dépendances système nécessaires (ex: pour psycopg2 ou cryptography)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc libpq-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copier le fichier des dépendances
COPY requirements.txt .

# Installer les dépendances Python
RUN pip install --no-cache-dir -r requirements.txt gunicorn

# Copier le reste du code de l'application
COPY . .

# Exposer le port (Render/Railway injectent leur propre PORT en variable d'environnement, par défaut 8000)
EXPOSE 8000

# Commande pour démarrer l'application avec Gunicorn (serveur de production) + Uvicorn (workers asynchrones)
# On écoute sur 0.0.0.0 pour que le conteneur soit accessible depuis l'extérieur
CMD ["gunicorn", "app.main:app", "-w", "4", "-k", "uvicorn.workers.UvicornWorker", "-b", "0.0.0.0:8000"]

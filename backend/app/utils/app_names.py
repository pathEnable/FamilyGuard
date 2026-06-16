"""
Mapping des noms de packages Android courants vers des noms lisibles et catégories.
Extensible : ajouter de nouvelles entrées au besoin.
"""

APP_REGISTRY: dict[str, dict[str, str]] = {
    # ── Réseaux Sociaux ──
    "com.instagram.android": {"name": "Instagram", "category": "Réseaux Sociaux", "icon": "📸"},
    "com.facebook.katana": {"name": "Facebook", "category": "Réseaux Sociaux", "icon": "👤"},
    "com.facebook.orca": {"name": "Messenger", "category": "Réseaux Sociaux", "icon": "💬"},
    "com.twitter.android": {"name": "X (Twitter)", "category": "Réseaux Sociaux", "icon": "🐦"},
    "com.snapchat.android": {"name": "Snapchat", "category": "Réseaux Sociaux", "icon": "👻"},
    "com.linkedin.android": {"name": "LinkedIn", "category": "Réseaux Sociaux", "icon": "💼"},
    "com.pinterest": {"name": "Pinterest", "category": "Réseaux Sociaux", "icon": "📌"},
    "com.reddit.frontpage": {"name": "Reddit", "category": "Réseaux Sociaux", "icon": "🔴"},
    "com.tumblr": {"name": "Tumblr", "category": "Réseaux Sociaux", "icon": "📝"},

    # ── Vidéo & Divertissement ──
    "com.google.android.youtube": {"name": "YouTube", "category": "Divertissement", "icon": "▶️"},
    "com.google.android.apps.youtube.kids": {"name": "YouTube Kids", "category": "Divertissement", "icon": "🧒"},
    "com.zhiliaoapp.musically": {"name": "TikTok", "category": "Divertissement", "icon": "🎵"},
    "com.netflix.mediaclient": {"name": "Netflix", "category": "Divertissement", "icon": "🎬"},
    "com.disney.disneyplus": {"name": "Disney+", "category": "Divertissement", "icon": "🏰"},
    "com.amazon.avod.thirdpartyclient": {"name": "Prime Video", "category": "Divertissement", "icon": "📺"},
    "tv.twitch.android.app": {"name": "Twitch", "category": "Divertissement", "icon": "🎮"},
    "com.spotify.music": {"name": "Spotify", "category": "Musique", "icon": "🎧"},
    "com.apple.android.music": {"name": "Apple Music", "category": "Musique", "icon": "🎶"},
    "com.deezer.android.app": {"name": "Deezer", "category": "Musique", "icon": "🎵"},

    # ── Messagerie ──
    "com.whatsapp": {"name": "WhatsApp", "category": "Messagerie", "icon": "💬"},
    "org.telegram.messenger": {"name": "Telegram", "category": "Messagerie", "icon": "✈️"},
    "com.discord": {"name": "Discord", "category": "Messagerie", "icon": "🎙️"},
    "com.viber.voip": {"name": "Viber", "category": "Messagerie", "icon": "📞"},
    "org.thoughtcrime.securesms": {"name": "Signal", "category": "Messagerie", "icon": "🔒"},

    # ── Jeux ──
    "com.supercell.clashofclans": {"name": "Clash of Clans", "category": "Jeux", "icon": "⚔️"},
    "com.supercell.clashroyale": {"name": "Clash Royale", "category": "Jeux", "icon": "🏰"},
    "com.kiloo.subwaysurf": {"name": "Subway Surfers", "category": "Jeux", "icon": "🏃"},
    "com.mojang.minecraftpe": {"name": "Minecraft", "category": "Jeux", "icon": "⛏️"},
    "com.innersloth.spacemafia": {"name": "Among Us", "category": "Jeux", "icon": "🚀"},
    "com.epicgames.fortnite": {"name": "Fortnite", "category": "Jeux", "icon": "🔫"},
    "com.king.candycrushsaga": {"name": "Candy Crush", "category": "Jeux", "icon": "🍬"},
    "com.roblox.client": {"name": "Roblox", "category": "Jeux", "icon": "🧱"},
    "com.ea.gp.fifamobile": {"name": "FIFA Mobile", "category": "Jeux", "icon": "⚽"},

    # ── Éducation ──
    "com.duolingo": {"name": "Duolingo", "category": "Éducation", "icon": "🦉"},
    "com.khan.academy": {"name": "Khan Academy", "category": "Éducation", "icon": "🎓"},
    "com.google.android.apps.classroom": {"name": "Google Classroom", "category": "Éducation", "icon": "📚"},
    "com.photomath.camera": {"name": "Photomath", "category": "Éducation", "icon": "📐"},
    "com.quizlet.quizletandroid": {"name": "Quizlet", "category": "Éducation", "icon": "📝"},

    # ── Navigateurs ──
    "com.android.chrome": {"name": "Chrome", "category": "Navigation", "icon": "🌐"},
    "org.mozilla.firefox": {"name": "Firefox", "category": "Navigation", "icon": "🦊"},
    "com.opera.browser": {"name": "Opera", "category": "Navigation", "icon": "🌐"},
    "com.brave.browser": {"name": "Brave", "category": "Navigation", "icon": "🦁"},
    "com.microsoft.emmx": {"name": "Edge", "category": "Navigation", "icon": "🌐"},
    "com.sec.android.app.sbrowser": {"name": "Samsung Internet", "category": "Navigation", "icon": "🌐"},

    # ── Google ──
    "com.google.android.gm": {"name": "Gmail", "category": "Productivité", "icon": "📧"},
    "com.google.android.apps.maps": {"name": "Google Maps", "category": "Utilitaire", "icon": "🗺️"},
    "com.google.android.apps.photos": {"name": "Google Photos", "category": "Utilitaire", "icon": "🖼️"},
    "com.google.android.apps.docs": {"name": "Google Docs", "category": "Productivité", "icon": "📄"},
    "com.google.android.calendar": {"name": "Google Calendar", "category": "Productivité", "icon": "📅"},
    "com.google.android.googlequicksearchbox": {"name": "Google", "category": "Utilitaire", "icon": "🔍"},

    # ── Système ──
    "com.android.settings": {"name": "Paramètres", "category": "Système", "icon": "⚙️"},
    "com.android.vending": {"name": "Play Store", "category": "Système", "icon": "🛒"},
    "com.android.camera2": {"name": "Appareil Photo", "category": "Système", "icon": "📷"},
    "com.samsung.android.app.camera": {"name": "Appareil Photo Samsung", "category": "Système", "icon": "📷"},
}


def get_app_info(package_name: str) -> dict[str, str]:
    """
    Retourne le nom lisible, la catégorie et l'icône pour un package donné.
    Si le package est inconnu, retourne un nom simplifié basé sur le package.
    """
    if package_name in APP_REGISTRY:
        return APP_REGISTRY[package_name]

    # Fallback: extraire un nom lisible du package name
    parts = package_name.split(".")
    # Prendre la dernière partie significative
    name = parts[-1] if len(parts) > 0 else package_name
    name = name.replace("_", " ").replace("-", " ").title()

    return {"name": name, "category": "Autre", "icon": "📱"}


def get_all_known_apps() -> list[dict[str, str]]:
    """Retourne la liste de toutes les apps connues avec leur info."""
    result = []
    for pkg, info in APP_REGISTRY.items():
        result.append({"package_name": pkg, **info})
    return result

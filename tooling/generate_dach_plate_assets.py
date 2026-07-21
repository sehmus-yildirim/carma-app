"""Generate local DACH plate presentation data and safe preview assets."""

from __future__ import annotations

import json
import re
import ssl
import urllib.request
from io import StringIO
from pathlib import Path

import pandas as pd
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
DATA_DIR = ASSETS / "data"
REPORT_DIR = ROOT / "tooling" / "reports"
GENERATED_DART = ROOT / "lib" / "shared" / "plate" / "dach_registration_region_data.g.dart"
USER_AGENT = "CaRismaAppData/1.0 (development-time generator)"

DE_STATES = {
    "Baden-Württemberg": ("BW", "baden_wuerttemberg"),
    "Bayern": ("BY", "bayern"),
    "Berlin": ("BE", "berlin"),
    "Brandenburg": ("BB", "brandenburg"),
    "Bremen": ("HB", "bremen"),
    "Hamburg": ("HH", "hamburg"),
    "Hessen": ("HE", "hessen"),
    "Mecklenburg-Vorpommern": ("MV", "mecklenburg_vorpommern"),
    "Niedersachsen": ("NI", "niedersachsen"),
    "Nordrhein-Westfalen": ("NW", "nordrhein_westfalen"),
    "Rheinland-Pfalz": ("RP", "rheinland_pfalz"),
    "Saarland": ("SL", "saarland"),
    "Sachsen": ("SN", "sachsen"),
    "Sachsen-Anhalt": ("ST", "sachsen_anhalt"),
    "Schleswig-Holstein": ("SH", "schleswig_holstein"),
    "Thüringen": ("TH", "thueringen"),
}

DE_SPECIAL_REGISTRATION_CODES = {
    "BD": "Dienstfahrzeuge des Bundes",
    "BP": "Bundespolizei",
    "BW": "Wasserstraßen- und Schifffahrtsverwaltung des Bundes",
    "THW": "Bundesanstalt Technisches Hilfswerk",
    "X": "Internationale militärische Hauptquartiere",
    "Y": "Bundeswehr",
}

AT_STATES = [
    (2, "B", "Burgenland", "burgenland"),
    (3, "K", "Kärnten", "kaernten"),
    (4, "N", "Niederösterreich", "niederoesterreich"),
    (5, "O", "Oberösterreich", "oberoesterreich"),
    (6, "S", "Salzburg", "salzburg"),
    (7, "ST", "Steiermark", "steiermark"),
    (8, "T", "Tirol", "tirol"),
    (9, "V", "Vorarlberg", "vorarlberg"),
    (10, "W", "Wien", "wien"),
]

CH_CANTONS = [
    ("AG", "Aargau"), ("AI", "Appenzell Innerrhoden"),
    ("AR", "Appenzell Ausserrhoden"), ("BE", "Bern"),
    ("BL", "Basel-Landschaft"), ("BS", "Basel-Stadt"),
    ("FR", "Freiburg / Fribourg"), ("GE", "Genf / Genève"),
    ("GL", "Glarus"), ("GR", "Graubünden / Grigioni / Grischun"),
    ("JU", "Jura"), ("LU", "Luzern"),
    ("NE", "Neuenburg / Neuchâtel"), ("NW", "Nidwalden"),
    ("OW", "Obwalden"), ("SG", "St. Gallen"),
    ("SH", "Schaffhausen"), ("SO", "Solothurn"),
    ("SZ", "Schwyz"), ("TG", "Thurgau"),
    ("TI", "Tessin / Ticino"), ("UR", "Uri"),
    ("VD", "Waadt / Vaud"), ("VS", "Wallis / Valais"),
    ("ZG", "Zug"), ("ZH", "Zürich"),
]


def fetch_html(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    context = ssl._create_unverified_context()
    return urllib.request.urlopen(request, context=context, timeout=60).read().decode("utf-8")


def supported_german_codes() -> list[str]:
    path = ROOT / "lib" / "shared" / "plate" / "german_plate_region_codes.dart"
    source = path.read_text(encoding="utf-8")
    data = re.search(r"'''(.*?)'''", source, re.DOTALL)
    if data is None:
        raise RuntimeError("German plate code list not found")
    return sorted(set(re.findall(r"[A-ZÄÖÜ]{1,3}", data.group(1))))


def clean(value: object) -> str:
    return re.sub(r"\s+", " ", str(value).replace("\xa0", " ").strip())


def german_data() -> list[dict[str, object]]:
    url = "https://de.wikipedia.org/wiki/Liste_der_Kfz-Kennzeichen_in_Deutschland"
    tables = pd.read_html(StringIO(fetch_html(url)))
    rows: dict[str, tuple[str, str]] = {}
    for table in [*tables[1:25], tables[26]]:
        for _, row in table.iterrows():
            match = re.match(r"^([A-ZÄÖÜ]{1,3})", clean(row.get("Abk.", "")))
            if match is None:
                continue
            code = match.group(1)
            region = clean(row.get("Stadt/Landkreis", ""))
            state = clean(row.get("Bundesland", ""))
            if code not in rows and state in DE_STATES:
                rows[code] = (region, state)

    result = []
    for code in supported_german_codes():
        region, state = rows.get(code, (f"Zulassungsregion {code}", ""))
        if code in DE_SPECIAL_REGISTRATION_CODES:
            region, state = DE_SPECIAL_REGISTRATION_CODES[code], "Bund"
        if code == "HB":
            region, state = "Freie Hansestadt Bremen", "Bremen"
        if code == "HH":
            region, state = "Hansestadt Hamburg", "Hamburg"
        state_code, slug = DE_STATES.get(state, ("DE", "de"))
        result.append({
            "countryCode": "DE", "plateCode": code,
            "authorityName": region, "displayName": region,
            "stateCode": state_code, "stateName": state or "Deutschland",
            "regionCoatAsset": f"assets/coats/de/states/{slug}.png",
            "plateSealAsset": f"assets/plate_seals/de/{slug}.png",
            "fallbackRequired": (
                code not in rows and code not in DE_SPECIAL_REGISTRATION_CODES
            ),
        })
    return result


def austria_data() -> list[dict[str, object]]:
    base = "https://www.oesterreich.gv.at/de/themen/mobilitaet/kfz/5/1/Seite.0614{:02d}"
    result = []
    for page, state_code, state_name, slug in AT_STATES:
        table = pd.read_html(StringIO(fetch_html(base.format(page))))[0]
        for _, row in table.iterrows():
            match = re.match(r"^([A-Z]{1,3})", clean(row.iloc[0]))
            if match is None:
                continue
            code = match.group(1)
            result.append({
                "countryCode": "AT", "plateCode": code,
                "authorityName": clean(row.iloc[2]),
                "displayName": clean(row.iloc[1]),
                "stateCode": state_code, "stateName": state_name,
                "regionCoatAsset": f"assets/coats/at/states/{slug}.png",
                "plateSealAsset": f"assets/plate_seals/at/{slug}.png",
                "fallbackRequired": False,
            })
    return sorted(result, key=lambda item: str(item["plateCode"]))


def switzerland_data() -> list[dict[str, object]]:
    return [{
        "countryCode": "CH", "plateCode": code,
        "authorityName": f"Kanton {name.split(' / ')[0]}",
        "displayName": name, "stateCode": code, "stateName": name,
        "regionCoatAsset": f"assets/coats/ch/cantons/{code.lower()}.png",
        "plateSealAsset": f"assets/plate_seals/ch/{code.lower()}.png",
        "fallbackRequired": False,
    } for code, name in CH_CANTONS]


def font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in [Path("C:/Windows/Fonts/segoeuib.ttf"), Path("C:/Windows/Fonts/arialbd.ttf")]:
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def save_flag(code: str) -> None:
    path = ASSETS / "flags" / f"{code.lower()}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGB", (180, 112), "white")
    draw = ImageDraw.Draw(image)
    if code == "DE":
        draw.rectangle((0, 0, 180, 37), fill="#000000")
        draw.rectangle((0, 37, 180, 75), fill="#DD0000")
        draw.rectangle((0, 75, 180, 112), fill="#FFCE00")
    elif code == "AT":
        draw.rectangle((0, 0, 180, 37), fill="#ED2939")
        draw.rectangle((0, 37, 180, 75), fill="#FFFFFF")
        draw.rectangle((0, 75, 180, 112), fill="#ED2939")
    else:
        draw.rectangle((0, 0, 180, 112), fill="#D52B1E")
        draw.rectangle((75, 22, 105, 90), fill="#FFFFFF")
        draw.rectangle((56, 41, 124, 71), fill="#FFFFFF")
    image.save(path, optimize=True)


def save_badge(path: Path, code: str, country: str, circular: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    color = {"DE": (30, 123, 255, 255), "AT": (221, 45, 58, 255), "CH": (213, 43, 30, 255)}[country]
    if circular:
        draw.ellipse((8, 8, 152, 152), fill=color, outline="white", width=6)
        draw.ellipse((22, 22, 138, 138), outline=(255, 255, 255, 90), width=3)
    else:
        shield = [(22, 15), (138, 15), (145, 77), (126, 126), (80, 151), (34, 126), (15, 77)]
        draw.polygon(shield, fill=color)
        draw.line(shield + [shield[0]], fill="white", width=6, joint="curve")
    large = font(50 if len(code) <= 2 else 39)
    small = font(20)
    box = draw.textbbox((0, 0), code, font=large)
    draw.text((80 - (box[2] - box[0]) / 2, 75 - (box[3] - box[1]) / 2), code, font=large, fill="white")
    box = draw.textbbox((0, 0), country, font=small)
    draw.text((80 - (box[2] - box[0]) / 2, 112), country, font=small, fill=(255, 255, 255, 210))
    image.save(path, optimize=True)


def write_assets() -> list[dict[str, object]]:
    manifest = []
    for country in ["DE", "AT", "CH"]:
        save_flag(country)
        manifest.append(asset_entry(f"assets/flags/{country.lower()}.png", "country", country, country, "geometric flag preview"))
    entries = [("DE", code, name, slug, "state") for name, (code, slug) in DE_STATES.items()]
    entries += [("AT", code, name, slug, "state") for _, code, name, slug in AT_STATES]
    entries += [("CH", code, name, code.lower(), "canton") for code, name in CH_CANTONS]
    entries.append(("DE", "DE", "Deutschland", "de", "country"))
    entries.append(("AT", "AT", "Österreich", "at", "country"))
    entries.append(("CH", "CH", "Schweiz", "ch", "country"))
    for country, code, name, slug, kind in entries:
        if country == "DE":
            coat = ASSETS / "coats/de/states" / f"{slug}.png"
            seal = ASSETS / "plate_seals/de" / f"{slug}.png"
        elif country == "AT":
            coat = ASSETS / "coats/at/states" / f"{slug}.png"
            seal = ASSETS / "plate_seals/at" / f"{slug}.png"
        else:
            coat = ASSETS / "coats/ch/cantons" / f"{slug}.png"
            seal = ASSETS / "plate_seals/ch" / f"{slug}.png"
        save_badge(coat, code, country)
        save_badge(seal, code, country, circular=True)
        manifest.append(asset_entry(coat.relative_to(ROOT).as_posix(), kind, code, name, "neutral regional preview"))
        manifest.append(asset_entry(seal.relative_to(ROOT).as_posix(), "plate_seal", code, name, "neutral plate preview"))
    confederation = ASSETS / "coats/ch/swiss_confederation.png"
    save_badge(confederation, "CH", "CH")
    manifest.append(asset_entry(confederation.relative_to(ROOT).as_posix(), "country", "CH", "Schweizerische Eidgenossenschaft", "neutral preview"))
    return manifest


def asset_entry(path: str, kind: str, code: str, name: str, reference: str) -> dict[str, object]:
    return {
        "assetPath": path, "entityType": kind, "entityId": code,
        "entityName": name, "sourceName": "CaRisma",
        "sourceReference": f"self-created {reference}",
        "license": "project-owned preview asset", "attributionRequired": False,
        "isOfficialOriginal": False, "isStylizedPreview": True,
    }


def dart_map(data: list[dict[str, object]]) -> dict[str, list[str]]:
    return {str(item["plateCode"]): [
        str(item["displayName"]), str(item["stateName"]), str(item["stateCode"]),
        str(item["regionCoatAsset"]), str(item["plateSealAsset"]),
        "true" if item["fallbackRequired"] else "false",
    ] for item in data}


def main() -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    de, at, ch = german_data(), austria_data(), switzerland_data()
    manifest = write_assets()
    values = {
        "de_registration_regions.json": de,
        "at_registration_districts.json": at,
        "ch_cantons.json": ch,
        "ch_municipalities.json": [],
        "emblem_asset_manifest.json": manifest,
    }
    for filename, value in values.items():
        (DATA_DIR / filename).write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    dart = "// GENERATED FILE. Run tooling/generate_dach_plate_assets.py to refresh.\n\n"
    for name, value in [("deRegistrationRegionData", dart_map(de)), ("atRegistrationRegionData", dart_map(at)), ("chRegistrationRegionData", dart_map(ch))]:
        dart += f"const Map<String, List<String>> {name} = {json.dumps(value, ensure_ascii=False, indent=2)};\n\n"
    GENERATED_DART.write_text(dart, encoding="utf-8")
    report = {
        "germany": {"registrationCodesTotal": len(de), "registrationCodesMapped": sum(not bool(x["fallbackRequired"]) for x in de), "municipalitiesTotal": 0, "municipalitiesMapped": 0, "stateAssets": 16, "missingAssets": [str(x["plateCode"]) for x in de if bool(x["fallbackRequired"])]},
        "austria": {"registrationCodesTotal": len(at), "registrationCodesMapped": len(at), "municipalitiesTotal": 0, "municipalitiesMapped": 0, "stateAssets": 9, "missingAssets": []},
        "switzerland": {"cantonsTotal": 26, "cantonsMapped": len(ch), "municipalitiesTotal": 0, "municipalitiesMapped": 0, "cantonAssets": 26, "missingAssets": []},
        "notes": ["The current search has no municipality selector.", "Coats and seals are project-owned stylized previews, not official security marks.", "Unknown runtime inputs use a neutral country fallback."],
    }
    (REPORT_DIR / "dach_region_asset_coverage.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated DE={len(de)}, AT={len(at)}, CH={len(ch)}, assets={len(manifest)}")


if __name__ == "__main__":
    main()

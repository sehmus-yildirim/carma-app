"""Replace generated DACH emblem previews with sourced Wikimedia coats."""

from __future__ import annotations

import html
import json
import re
import shutil
import time
import urllib.parse
import urllib.request
from urllib.error import HTTPError
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "assets" / "data" / "emblem_asset_manifest.json"
USER_AGENT = "CaRismaAppData/1.0 (contact: info@carisma.de)"

PAGES = {
    "DE": {
        "baden_wuerttemberg": "Baden-Württemberg",
        "bayern": "Bayern",
        "berlin": "Berlin",
        "brandenburg": "Brandenburg",
        "bremen": "Bremen",
        "hamburg": "Hamburg",
        "hessen": "Hessen",
        "mecklenburg_vorpommern": "Mecklenburg-Vorpommern",
        "niedersachsen": "Niedersachsen",
        "nordrhein_westfalen": "Nordrhein-Westfalen",
        "rheinland_pfalz": "Rheinland-Pfalz",
        "saarland": "Saarland",
        "sachsen": "Sachsen",
        "sachsen_anhalt": "Sachsen-Anhalt",
        "schleswig_holstein": "Schleswig-Holstein",
        "thueringen": "Thüringen",
    },
    "AT": {
        "burgenland": "Burgenland",
        "kaernten": "Kärnten",
        "niederoesterreich": "Niederösterreich",
        "oberoesterreich": "Oberösterreich",
        "salzburg": "Salzburg (Bundesland)",
        "steiermark": "Steiermark",
        "tirol": "Tirol (Bundesland)",
        "vorarlberg": "Vorarlberg",
        "wien": "Wien",
    },
    "CH": {
        "ag": "Kanton Aargau",
        "ai": "Kanton Appenzell Innerrhoden",
        "ar": "Kanton Appenzell Ausserrhoden",
        "be": "Kanton Bern",
        "bl": "Kanton Basel-Landschaft",
        "bs": "Kanton Basel-Stadt",
        "fr": "Kanton Freiburg",
        "ge": "Kanton Genf",
        "gl": "Kanton Glarus",
        "gr": "Kanton Graubünden",
        "ju": "Kanton Jura",
        "lu": "Kanton Luzern",
        "ne": "Kanton Neuenburg",
        "nw": "Kanton Nidwalden",
        "ow": "Kanton Obwalden",
        "sg": "Kanton St. Gallen",
        "sh": "Kanton Schaffhausen",
        "so": "Kanton Solothurn",
        "sz": "Kanton Schwyz",
        "tg": "Kanton Thurgau",
        "ti": "Kanton Tessin",
        "ur": "Kanton Uri",
        "vd": "Kanton Waadt",
        "vs": "Kanton Wallis",
        "zg": "Kanton Zug",
        "zh": "Kanton Zürich",
    },
}


def open_request(request: urllib.request.Request):
    for attempt in range(6):
        try:
            return urllib.request.urlopen(request, timeout=60)
        except HTTPError as error:
            if error.code != 429 or attempt == 5:
                raise
            wait_seconds = int(error.headers.get("Retry-After", "8"))
            time.sleep(max(wait_seconds, 8) * (attempt + 1))
    raise RuntimeError("Request retry limit reached")


def api_json(host: str, params: dict[str, str]) -> dict[str, object]:
    query = urllib.parse.urlencode(params)
    request = urllib.request.Request(
        f"https://{host}/w/api.php?{query}",
        headers={"User-Agent": USER_AGENT},
    )
    with open_request(request) as response:
        return json.load(response)


def wikidata_id(page_title: str) -> str:
    payload = api_json(
        "de.wikipedia.org",
        {
            "action": "query",
            "prop": "pageprops",
            "ppprop": "wikibase_item",
            "redirects": "1",
            "titles": page_title,
            "format": "json",
        },
    )
    pages = payload["query"]["pages"]
    page = next(iter(pages.values()))
    return page.get("pageprops", {}).get("wikibase_item", "")


def coat_filename(entity_id: str) -> str:
    payload = api_json(
        "www.wikidata.org",
        {
            "action": "wbgetclaims",
            "entity": entity_id,
            "property": "P94",
            "format": "json",
        },
    )
    claims = payload.get("claims", {}).get("P94", [])
    preferred = [claim for claim in claims if claim.get("rank") == "preferred"]
    for claim in [*preferred, *claims]:
        value = (
            claim.get("mainsnak", {})
            .get("datavalue", {})
            .get("value")
        )
        if isinstance(value, str) and value:
            return value
    return ""


def clean_html(value: str) -> str:
    return html.unescape(re.sub(r"<[^>]+>", "", value)).strip()


def image_info(filename: str) -> dict[str, str]:
    payload = api_json(
        "commons.wikimedia.org",
        {
            "action": "query",
            "prop": "imageinfo",
            "iiprop": "url|extmetadata",
            "iiurlwidth": "512",
            "titles": f"File:{filename}",
            "format": "json",
        },
    )
    pages = payload["query"]["pages"]
    page = next(iter(pages.values()))
    info = page.get("imageinfo", [{}])[0]
    metadata = info.get("extmetadata", {})
    return {
        "downloadUrl": info.get("thumburl") or info.get("url", ""),
        "descriptionUrl": info.get("descriptionurl", ""),
        "license": clean_html(
            metadata.get("LicenseShortName", {}).get("value", "Unbekannt")
        ),
        "artist": clean_html(metadata.get("Artist", {}).get("value", "")),
    }


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    destination.parent.mkdir(parents=True, exist_ok=True)
    with open_request(request) as response:
        with destination.open("wb") as output:
            shutil.copyfileobj(response, output)
    time.sleep(1)


def batched_source_data(
    pages: dict[str, str],
) -> dict[str, tuple[str, dict[str, str]]]:
    title_payload = api_json(
        "de.wikipedia.org",
        {
            "action": "query",
            "prop": "pageprops",
            "ppprop": "wikibase_item",
            "redirects": "1",
            "titles": "|".join(pages.values()),
            "format": "json",
        },
    )
    aliases = {
        item["from"]: item["to"]
        for group in ("normalized", "redirects")
        for item in title_payload.get("query", {}).get(group, [])
    }
    wiki_pages = title_payload.get("query", {}).get("pages", {}).values()
    entity_by_title = {
        page.get("title", ""): page.get("pageprops", {}).get("wikibase_item", "")
        for page in wiki_pages
    }

    entity_by_slug: dict[str, str] = {}
    for slug, title in pages.items():
        resolved = title
        while resolved in aliases:
            resolved = aliases[resolved]
        entity_by_slug[slug] = entity_by_title.get(resolved, "")

    entity_ids = [value for value in entity_by_slug.values() if value]
    entity_payload = api_json(
        "www.wikidata.org",
        {
            "action": "wbgetentities",
            "ids": "|".join(entity_ids),
            "props": "claims",
            "format": "json",
        },
    )
    filename_by_entity: dict[str, str] = {}
    for entity_id, entity in entity_payload.get("entities", {}).items():
        claims = entity.get("claims", {}).get("P94", [])
        preferred = [claim for claim in claims if claim.get("rank") == "preferred"]
        for claim in [*preferred, *claims]:
            value = (
                claim.get("mainsnak", {})
                .get("datavalue", {})
                .get("value")
            )
            if isinstance(value, str) and value:
                filename_by_entity[entity_id] = value
                break

    filenames = list(filename_by_entity.values())
    image_payload = api_json(
        "commons.wikimedia.org",
        {
            "action": "query",
            "prop": "imageinfo",
            "iiprop": "url|extmetadata",
            "iiurlwidth": "512",
            "titles": "|".join(f"File:{value}" for value in filenames),
            "format": "json",
        },
    )
    info_by_filename: dict[str, dict[str, str]] = {}
    for page in image_payload.get("query", {}).get("pages", {}).values():
        filename = page.get("title", "").removeprefix("File:")
        info = page.get("imageinfo", [{}])[0]
        metadata = info.get("extmetadata", {})
        info_by_filename[filename.casefold().replace("_", " ")] = {
            "downloadUrl": info.get("thumburl") or info.get("url", ""),
            "descriptionUrl": info.get("descriptionurl", ""),
            "license": clean_html(
                metadata.get("LicenseShortName", {}).get("value", "Unbekannt")
            ),
            "artist": clean_html(metadata.get("Artist", {}).get("value", "")),
        }

    result: dict[str, tuple[str, dict[str, str]]] = {}
    for slug, entity_id in entity_by_slug.items():
        filename = filename_by_entity.get(entity_id, "")
        info = info_by_filename.get(filename.casefold().replace("_", " "), {})
        result[slug] = (filename, info)
    return result


def asset_paths(country: str, slug: str) -> tuple[Path, Path]:
    if country == "DE":
        coat = ROOT / "assets" / "coats" / "de" / "states" / f"{slug}.png"
        seal = ROOT / "assets" / "plate_seals" / "de" / f"{slug}.png"
    elif country == "AT":
        coat = ROOT / "assets" / "coats" / "at" / "states" / f"{slug}.png"
        seal = ROOT / "assets" / "plate_seals" / "at" / f"{slug}.png"
    else:
        coat = ROOT / "assets" / "coats" / "ch" / "cantons" / f"{slug}.png"
        seal = ROOT / "assets" / "plate_seals" / "ch" / f"{slug}.png"
    return coat, seal


def update_manifest(
    manifest: list[dict[str, object]],
    path: Path,
    page_title: str,
    info: dict[str, str],
) -> None:
    relative = path.relative_to(ROOT).as_posix()
    for entry in manifest:
        if entry.get("assetPath") != relative:
            continue
        entry.update(
            {
                "sourceName": "Wikimedia Commons",
                "sourceReference": info["descriptionUrl"],
                "sourcePage": page_title,
                "artist": info["artist"],
                "license": info["license"],
                "attributionRequired": True,
                "isOfficialOriginal": True,
                "isStylizedPreview": False,
            }
        )
        return


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    completed = 0
    missing: list[str] = []
    for country, pages in PAGES.items():
        sources = batched_source_data(pages)
        for slug, page_title in pages.items():
            _, info = sources.get(slug, ("", {}))
            download_url = info.get("downloadUrl", "")
            if not download_url:
                missing.append(f"{country}:{page_title}")
                continue
            coat, seal = asset_paths(country, slug)
            already_downloaded = (
                coat.exists()
                and seal.exists()
                and coat.stat().st_size > 10_000
                and seal.stat().st_size > 10_000
            )
            if not already_downloaded:
                download(download_url, coat)
                shutil.copyfile(coat, seal)
            update_manifest(manifest, coat, page_title, info)
            update_manifest(manifest, seal, page_title, info)
            completed += 1

    MANIFEST_PATH.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Downloaded {completed} regional coats.")
    if missing:
        print("Missing: " + ", ".join(missing))


if __name__ == "__main__":
    main()

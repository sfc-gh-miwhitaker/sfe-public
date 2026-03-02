"""
Glaze & Classify — SPCS Image Classification Service

Lightweight HTTP service that classifies bakery/donut product images.
Uses a rule-based approach on image URLs (since real images are example URLs)
combined with a simple heuristic classifier to demonstrate the SPCS pattern.

In production, this would load a fine-tuned image classification model
(e.g., ResNet, EfficientNet) trained on actual product photos.
"""

import json
import logging
import re
from http.server import HTTPServer, BaseHTTPRequestHandler

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("glaze-vision")

CATEGORY_MAP = {
    "glazed":       ("Glazed", "Original Glazed"),
    "original":     ("Glazed", "Original Glazed"),
    "choc-glazed":  ("Glazed", "Chocolate Glazed"),
    "double-choc":  ("Glazed", "Chocolate Glazed"),
    "maple":        ("Glazed", "Maple Glazed"),
    "strawberry":   ("Glazed", "Strawberry Glazed"),
    "choc-frosted": ("Frosted", "Chocolate Frosted"),
    "frosted":      ("Frosted", "Chocolate Frosted"),
    "vanilla":      ("Frosted", "Vanilla Frosted"),
    "sprinkle":     ("Frosted", "Sprinkle Frosted"),
    "hundreds":     ("Frosted", "Sprinkle Frosted"),
    "cream":        ("Filled", "Cream Filled"),
    "custard":      ("Filled", "Cream Filled"),
    "bavarian":     ("Filled", "Cream Filled"),
    "jelly":        ("Filled", "Jelly Filled"),
    "jam":          ("Filled", "Jelly Filled"),
    "goiabada":     ("Filled", "Jelly Filled"),
    "choc-kreme":   ("Filled", "Chocolate Filled"),
    "brigadeiro":   ("Filled", "Chocolate Filled"),
    "ganache":      ("Filled", "Chocolate Filled"),
    "cake":         ("Cake", "Plain Cake"),
    "blueberry":    ("Cake", "Blueberry Cake"),
    "cinnamon":     ("Cake", "Cinnamon Cake"),
    "canela":       ("Cake", "Cinnamon Cake"),
    "churro":       ("Cake", "Cinnamon Cake"),
    "cruller":      ("Specialty", "Cruller"),
    "old-fashion":  ("Specialty", "Old Fashioned"),
    "bear-claw":    ("Specialty", "Bear Claw"),
    "pumpkin":      ("Seasonal", "Pumpkin Spice"),
    "peppermint":   ("Seasonal", "Peppermint"),
    "sakura":       ("Seasonal", "Sakura"),
    "matcha":       ("Seasonal", "Sakura"),
    "coffee":       ("Beverages", "Hot Coffee"),
    "cafe":         ("Beverages", "Hot Coffee"),
    "latte":        ("Beverages", "Iced Coffee"),
    "iced":         ("Beverages", "Iced Coffee"),
    "hot-choc":     ("Beverages", "Hot Chocolate"),
    "tshirt":       ("Merchandise", "Apparel"),
    "hoodie":       ("Merchandise", "Apparel"),
    "playera":      ("Merchandise", "Apparel"),
    "camiseta":     ("Merchandise", "Apparel"),
    "mug":          ("Merchandise", "Accessories"),
    "tote":         ("Merchandise", "Accessories"),
}


def classify_image(image_url: str) -> dict:
    """Classify a bakery product based on its image URL.

    In production, this would download the image and run inference.
    For this demo, we extract signals from the URL path to simulate
    what a trained vision model would return.
    """
    if not image_url:
        return {
            "category": None,
            "subcategory": None,
            "confidence": 0.0
        }

    url_lower = image_url.lower()
    best_match = None
    best_confidence = 0.0

    for keyword, (category, subcategory) in CATEGORY_MAP.items():
        if keyword in url_lower:
            match_len = len(keyword)
            confidence = min(0.65 + (match_len / 40.0), 0.95)
            if confidence > best_confidence:
                best_match = (category, subcategory)
                best_confidence = confidence

    if best_match:
        return {
            "category": best_match[0],
            "subcategory": best_match[1],
            "confidence": round(best_confidence, 4)
        }

    return {
        "category": "Glazed",
        "subcategory": "Original Glazed",
        "confidence": 0.25
    }


class ClassificationHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == "/classify":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length)
            request = json.loads(body)

            results = []
            for row in request.get("data", []):
                row_index = row[0]
                image_url = row[1] if len(row) > 1 else None
                result = classify_image(image_url)
                results.append([row_index, json.dumps(result)])

            response = json.dumps({"data": results})
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(response.encode())

        elif self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status": "healthy"}')
        else:
            self.send_response(404)
            self.end_headers()

    def do_GET(self):
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(b'{"status": "healthy"}')
        else:
            self.send_response(404)
            self.end_headers()


def main():
    port = 8080
    server = HTTPServer(("0.0.0.0", port), ClassificationHandler)
    logger.info(f"Glaze Vision Service running on port {port}")
    server.serve_forever()


if __name__ == "__main__":
    main()

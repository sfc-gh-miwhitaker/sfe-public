#!/usr/bin/env python3
"""Generate professional PDF documents from the synthetic financial document content.

Reads sql/02_data/06_load_documents.sql, parses each INSERT row, and writes
a formatted PDF per document into the documents/ folder.

Requirements: pip install fpdf2
Usage:        python scripts/generate_pdfs.py
"""

import os
import re
import sys
from pathlib import Path

from fpdf import FPDF

PROJECT_ROOT = Path(__file__).resolve().parent.parent
SQL_FILE = PROJECT_ROOT / "sql" / "02_data" / "06_load_documents.sql"
OUTPUT_DIR = PROJECT_ROOT / "documents"

DOC_TYPE_LABELS = {
    "credit_committee_memo": "CREDIT COMMITTEE MEMORANDUM",
    "covenant_compliance_certificate": "COVENANT COMPLIANCE CERTIFICATE",
    "collateral_appraisal": "INDEPENDENT APPRAISAL REPORT",
    "amendment_letter": "AMENDMENT LETTER",
    "annual_review": "ANNUAL CREDIT REVIEW",
    "borrower_financial_analysis": "BORROWER FINANCIAL ANALYSIS",
}

DOC_TYPE_COLORS = {
    "credit_committee_memo": (0, 51, 102),
    "covenant_compliance_certificate": (0, 102, 51),
    "collateral_appraisal": (102, 51, 0),
    "amendment_letter": (102, 0, 51),
    "annual_review": (51, 51, 102),
    "borrower_financial_analysis": (51, 102, 102),
}


def parse_sql_inserts(sql_path: Path) -> list[dict]:
    """Extract document rows from the SQL INSERT file."""
    text = sql_path.read_text(encoding="utf-8")

    pattern = re.compile(
        r"\('(D-\d+)',\s*'([^']+)',\s*'([^']+)',\s*\n\s*'([^']*(?:''[^']*)*)',\s*\n"
        r"\s*'((?:[^'\\]|\\.|'')*)',\s*\n"
        r"\s*'([^']*(?:''[^']*)*)',\s*'(\d{4}-\d{2}-\d{2})'\)",
        re.DOTALL,
    )

    docs = []
    for m in pattern.finditer(text):
        content_raw = m.group(5)
        content_raw = content_raw.replace("\\'", "'").replace("''", "'")
        content_raw = content_raw.replace("\\n", "\n")

        docs.append(
            {
                "doc_id": m.group(1),
                "facility_id": m.group(2),
                "doc_type": m.group(3),
                "title": m.group(4).replace("''", "'"),
                "content": content_raw,
                "author": m.group(6).replace("''", "'"),
                "created_date": m.group(7),
            }
        )
    return docs


class FinancialPDF(FPDF):
    """Styled PDF for specialty finance documents."""

    def __init__(self, doc_type: str, title: str, **kwargs):
        super().__init__(**kwargs)
        self.doc_type = doc_type
        self.doc_title = title
        r, g, b = DOC_TYPE_COLORS.get(doc_type, (51, 51, 51))
        self.header_color = (r, g, b)

    def header(self):
        self.set_font("Helvetica", "B", 8)
        self.set_text_color(128, 128, 128)
        label = DOC_TYPE_LABELS.get(self.doc_type, self.doc_type.upper())
        self.cell(0, 5, f"CONFIDENTIAL  |  {label}", align="C", new_x="LMARGIN", new_y="NEXT")

        r, g, b = self.header_color
        self.set_draw_color(r, g, b)
        self.set_line_width(0.8)
        self.line(10, self.get_y() + 1, self.w - 10, self.get_y() + 1)
        self.ln(5)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 7)
        self.set_text_color(160, 160, 160)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}  |  Specialty Finance Direct Lending Group  |  SYNTHETIC DATA - FOR DEMONSTRATION ONLY", align="C")


def _safe_multi_cell(pdf: FPDF, w: float, h: float, text: str):
    """multi_cell with X-position safety check."""
    pdf.set_x(pdf.l_margin)
    pdf.multi_cell(w, h, text)


def render_content(pdf: FinancialPDF, content: str):
    """Parse content string and render with formatting."""
    lines = content.split("\n")
    for line in lines:
        stripped = line.strip()

        if not stripped:
            pdf.ln(3)
            continue

        if stripped.isupper() and len(stripped) > 3 and ":" not in stripped:
            pdf.ln(2)
            pdf.set_font("Helvetica", "B", 11)
            r, g, b = pdf.header_color
            pdf.set_text_color(r, g, b)
            pdf.set_x(pdf.l_margin)
            pdf.cell(0, 6, stripped, new_x="LMARGIN", new_y="NEXT")
            pdf.ln(1)
            continue

        if re.match(r"^\d+\.\s+", stripped):
            pdf.set_font("Helvetica", "B", 9)
            pdf.set_text_color(40, 40, 40)
            _safe_multi_cell(pdf, 0, 5, stripped)
            continue

        if stripped.startswith("- "):
            pdf.set_font("Helvetica", "", 9)
            pdf.set_text_color(60, 60, 60)
            _safe_multi_cell(pdf, 0, 5, f"  -  {stripped[2:]}")
            continue

        is_label_value = re.match(r"^([A-Z][A-Za-z\s/&()]+):\s*(.+)$", stripped)
        if is_label_value and len(is_label_value.group(1)) < 40:
            pdf.set_font("Helvetica", "B", 9)
            pdf.set_text_color(40, 40, 40)
            _safe_multi_cell(pdf, 0, 5, stripped)
            continue

        pdf.set_font("Helvetica", "", 9)
        pdf.set_text_color(60, 60, 60)
        _safe_multi_cell(pdf, 0, 5, stripped)


def generate_pdf(doc: dict, output_dir: Path):
    """Generate a single PDF document."""
    pdf = FinancialPDF(doc["doc_type"], doc["title"])
    pdf.alias_nb_pages()
    pdf.set_auto_page_break(auto=True, margin=20)
    pdf.add_page()

    r, g, b = pdf.header_color
    pdf.set_font("Helvetica", "B", 14)
    pdf.set_text_color(r, g, b)
    pdf.multi_cell(0, 7, doc["title"])
    pdf.ln(3)

    pdf.set_font("Helvetica", "", 8)
    pdf.set_text_color(100, 100, 100)
    meta_line = f"Document ID: {doc['doc_id']}  |  Facility: {doc['facility_id']}  |  Date: {doc['created_date']}  |  Author: {doc['author']}"
    pdf.cell(0, 4, meta_line, new_x="LMARGIN", new_y="NEXT")

    pdf.set_draw_color(200, 200, 200)
    pdf.set_line_width(0.3)
    pdf.line(10, pdf.get_y() + 2, pdf.w - 10, pdf.get_y() + 2)
    pdf.ln(6)

    render_content(pdf, doc["content"])

    filename = f"{doc['doc_id']}.pdf"
    pdf.output(str(output_dir / filename))
    return filename


def main():
    if not SQL_FILE.exists():
        print(f"ERROR: SQL file not found: {SQL_FILE}", file=sys.stderr)
        sys.exit(1)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    docs = parse_sql_inserts(SQL_FILE)
    if not docs:
        print("ERROR: No documents parsed from SQL file.", file=sys.stderr)
        print("Falling back to generating from embedded content...", file=sys.stderr)
        sys.exit(1)

    print(f"Parsed {len(docs)} documents from {SQL_FILE.name}")

    type_counts: dict[str, int] = {}
    for doc in docs:
        filename = generate_pdf(doc, OUTPUT_DIR)
        dt = doc["doc_type"]
        type_counts[dt] = type_counts.get(dt, 0) + 1
        print(f"  [{doc['doc_id']}] {filename} ({dt})")

    print(f"\nGenerated {len(docs)} PDFs in {OUTPUT_DIR}/")
    for dt, count in sorted(type_counts.items()):
        print(f"  {DOC_TYPE_LABELS.get(dt, dt)}: {count}")


if __name__ == "__main__":
    main()

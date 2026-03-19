#!/usr/bin/env python3
"""
Blood Pressure PDF to CSV Converter
从健康App导出的血压PDF文件中提取数据并生成CSV文件

Usage:
    python3 pdf_to_csv.py <input.pdf> [output.csv]

CSV Output Format:
    date,time,period,systolic,diastolic,heart_rate
    2026-03-19,06:17,AM,126,93,0
"""

import subprocess
import sys
import os
import re
import csv
import unicodedata


def install_dependencies():
    """Install required Python packages if missing."""
    required = ["pdfplumber"]
    for pkg in required:
        try:
            __import__(pkg)
        except ImportError:
            print(f"Installing {pkg}...")
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", pkg],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            print(f"  ✅ {pkg} installed")


install_dependencies()
import pdfplumber


def normalize_text(text: str) -> str:
    """Normalize CJK compatibility characters to standard Unicode.

    Health app PDFs often use CJK radical characters (e.g. ⽉ U+2F42)
    instead of standard CJK characters (e.g. 月 U+6708).
    NFKC normalization converts them to standard forms.
    """
    return unicodedata.normalize("NFKC", text)


def extract_readings_from_pdf(pdf_path: str) -> list[dict]:
    """Extract blood pressure readings from a Health app exported PDF."""
    readings = []

    # Pattern: 数值/数值, 上午/下午 H:MM
    bp_pattern = re.compile(
        r"(\d{2,3})/(\d{2,3}),\s*(上午|下午)\s*(\d{1,2}):(\d{2})"
    )
    # Pattern: date like "2026年3月19日"
    date_pattern = re.compile(
        r"(\d{4})\s*年\s*(\d{1,2})\s*月\s*(\d{1,2})\s*日"
    )

    with pdfplumber.open(pdf_path) as pdf:
        for page in pdf.pages:
            raw_text = page.extract_text() or ""
            text = normalize_text(raw_text)
            lines = text.split("\n")

            current_date = None

            for line in lines:
                # Try to find a date
                date_match = date_pattern.search(line)
                if date_match:
                    year = int(date_match.group(1))
                    month = int(date_match.group(2))
                    day = int(date_match.group(3))
                    current_date = f"{year:04d}-{month:02d}-{day:02d}"

                # Find all BP readings on this line
                for bp_match in bp_pattern.finditer(line):
                    if current_date is None:
                        continue

                    systolic = int(bp_match.group(1))
                    diastolic = int(bp_match.group(2))
                    ampm = bp_match.group(3)
                    hour = int(bp_match.group(4))
                    minute = int(bp_match.group(5))

                    # Convert to 24-hour format
                    if ampm == "下午" and hour != 12:
                        hour += 12
                    elif ampm == "上午" and hour == 12:
                        hour = 0

                    period = "AM" if ampm == "上午" else "PM"
                    time_str = f"{hour:02d}:{minute:02d}"

                    # Validate ranges
                    if 50 < systolic < 300 and 30 < diastolic < 200:
                        readings.append(
                            {
                                "date": current_date,
                                "time": time_str,
                                "period": period,
                                "systolic": systolic,
                                "diastolic": diastolic,
                                "heart_rate": 0,
                            }
                        )

    # Sort by date and time
    readings.sort(key=lambda r: f"{r['date']} {r['time']}")

    # Remove duplicates
    seen = set()
    unique = []
    for r in readings:
        key = (r["date"], r["time"], r["systolic"], r["diastolic"])
        if key not in seen:
            seen.add(key)
            unique.append(r)

    return unique


def write_csv(readings: list[dict], output_path: str):
    """Write readings to CSV file."""
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["date", "time", "period", "systolic", "diastolic", "heart_rate"])
        for r in readings:
            writer.writerow(
                [r["date"], r["time"], r["period"], r["systolic"], r["diastolic"], r["heart_rate"]]
            )


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 pdf_to_csv.py <input.pdf> [output.csv]")
        sys.exit(1)

    pdf_path = sys.argv[1]
    if not os.path.exists(pdf_path):
        print(f"Error: File not found: {pdf_path}")
        sys.exit(1)

    # Default output path
    if len(sys.argv) >= 3:
        output_path = sys.argv[2]
    else:
        base = os.path.splitext(os.path.basename(pdf_path))[0]
        output_path = os.path.join(os.path.dirname(pdf_path) or ".", f"{base}.csv")

    print(f"📄 Reading PDF: {pdf_path}")
    readings = extract_readings_from_pdf(pdf_path)

    if not readings:
        print("❌ No blood pressure readings found in PDF")
        sys.exit(1)

    write_csv(readings, output_path)

    print(f"✅ Extracted {len(readings)} readings")
    print(f"📅 Date range: {readings[0]['date']} ~ {readings[-1]['date']}")
    print(f"💾 CSV saved to: {output_path}")


if __name__ == "__main__":
    main()

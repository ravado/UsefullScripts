# 
# This script is used to parse EPUB files and extract the content into separate text files.
# The content is organized by month and day, with each day's content in a separate file.
# The script assumes that the EPUB file has a specific structure, with the content divided into
# sections labeled with the month and day of the publication.
# 
# Notes: This is not generating the end clean result for all files and may require some manual adjutments
# so when regenerating articles keep that in mind

import os
import shutil
import ebooklib
from ebooklib import epub
from datetime import datetime
from bs4 import BeautifulSoup

def clear_directory(directory):
    """Deletes all files in the specified directory."""
    for filename in os.listdir(directory):
        file_path = os.path.join(directory, filename)
        try:
            if os.path.isfile(file_path) or os.path.islink(file_path):
                os.unlink(file_path)  # Remove file or link
            elif os.path.isdir(file_path):
                shutil.rmtree(file_path)  # Remove directory and all its contents
        except Exception as e:
            print(f'Failed to delete {file_path}. Reason: {e}')

def get_filename_with_cyrillic_month(date_text):
    # Ukrainian month names in Cyrillic mapped to month numbers
    months_uk = {
        'січня': '01', 'лютого': '02', 'березня': '03', 'квітня': '04',
        'травня': '05', 'червня': '06', 'липня': '07', 'серпня': '08',
        'вересня': '09', 'жовтня': '10', 'листопада': '11', 'грудня': '12'
    }
    day, month_name = date_text.split()
    month = months_uk.get(month_name)  # Get month number from the dictionary
    return f"{month}-{day.zfill(2)} ({date_text}).txt"  # Format: MM-DD (Day Month).txt

def clean_text(tag):
    for s in tag.select('span, a'):
        s.decompose()  # Remove all span and a tags, including nested ones
    return ' '.join(tag.stripped_strings)  # Combine strings and strip extra whitespace

def extract_and_save_content(epub_path, output_dir):
    book = epub.read_epub(epub_path)
    os.makedirs(output_dir, exist_ok=True)

    for item in book.get_items():
        if item.get_type() == ebooklib.ITEM_DOCUMENT:
            soup = BeautifulSoup(item.content, 'html.parser')
            date_tag = soup.find('h4', class_='running-headers_running-number')
            if date_tag:
                date_text = date_tag.text.strip()
                filename = get_filename_with_cyrillic_month(date_text)
                filepath = os.path.join(output_dir, filename)

                content_div = soup.find('div', class_='idGenObjectStyleOverride-1')
                if content_div:
                    with open(filepath, 'w', encoding='utf-8') as file:
                        # Write the date and title in bold tags
                        file.write(f"<b>{date_text}</b>\n\n")
                        title_tag = soup.find('h4', class_='running-headers_running-header')
                        if title_tag:
                            file.write(f"<b>{clean_text(title_tag)}</b>\n\n")

                        # Process elements in the order they appear
                        for element in content_div.children:
                            if element.name == 'p':
                                text = clean_text(element)
                                if 'quote_verse' in element.get('class', []):
                                    # Handle verses specially to avoid extra new lines
                                    file.write(f"<i>{text}</i>\n")
                                elif text:
                                    file.write(f"{text}\n\n")
                            elif element.name == 'h6' and 'additional_epigraph' in element.get('class', []):
                                quote_text = clean_text(element)
                                author = element.find_next_sibling('h6', class_='additional_epigraph-author')
                                if author:
                                    author_text = clean_text(author)
                                    file.write(f"<blockquote>{quote_text}\n\n<i><b>{author_text}</b></i></blockquote>\n\n")
                                else:
                                    file.write(f"<blockquote>{quote_text}</blockquote>\n\n")

                        print(f"Saved: {filepath}")

                    # Read back the content, trim end, and rewrite
                    content = None
                    with open(filepath, 'r', encoding='utf-8') as file:
                        content = file.read().rstrip()

                    with open(filepath, 'w', encoding='utf-8') as file:
                        file.write(content)

if __name__ == "__main__":
    epub_path = 'book/parents/tatovi-na-schoden-366.epub'
    output_dir = 'daily_articles/parent'
    extract_and_save_content(epub_path, output_dir)
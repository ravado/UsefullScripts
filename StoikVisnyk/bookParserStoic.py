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

def convert_to_mm_dd_format(date_str):
    # Ukrainian month name to number mapping
    months = {
        "січня": "01", "лютого": "02", "березня": "03", "квітня": "04",
        "травня": "05", "червня": "06", "липня": "07", "серпня": "08",
        "вересня": "09", "жовтня": "10", "листопада": "11", "грудня": "12"
    }
    # Split the date string into day and month
    parts = date_str.split()
    if len(parts) == 2:
        day, month_name = parts
        month = months.get(month_name)
        if month:
            # Format date as MM-DD
            return f"{month}-{day.zfill(2)}", date_str
    return None, date_str

def extract_and_save_content(epub_path, output_dir):
    # Load the EPUB book
    book = epub.read_epub(epub_path)
    
    # Ensure the output directory exists
    os.makedirs(output_dir, exist_ok=True)
    clear_directory(output_dir)  # Clear all files before processing

    # Iterate over all items in the EPUB
    for item in book.get_items():
        if item.get_type() == ebooklib.ITEM_DOCUMENT:
            # Parse the HTML content
            soup = BeautifulSoup(item.content, 'html.parser')
            
            # Find the content division
            content_div = soup.find('div', class_='Базовий-текстовий-кадр')

            if content_div:
                # Handle transformations
                for a in content_div.find_all('a'):
                    a.decompose()
                
                for span in content_div.find_all('span'):
                    span.unwrap()
                
                for em in content_div.find_all('em'):
                    em.name = 'b'
                    del em['class']
                
                for h4 in content_div.find_all('h4', class_='Розділ-номер'):
                    # h4.name = 'b'
                    # del h4['class']
                    h4.unwrap()

                
                for h3 in content_div.find_all('h3', class_='Розділ-назва'):
                    h3.name = 'b'
                    del h3['class']
                
                # for p in content_div.find_all('p', class_='Цитата-1-й'):
                #     p.name = 'blockquote'
                #     del p['class']
                
                # for p in content_div.find_all('p', class_='цитата-підпис'):
                #     p.name = 'blockquote'
                #     # p.insert(0, BeautifulSoup('<b></b>', 'html.parser'))
                #     # p.b.string = p.text
                #     text_only = p.get_text()  # Extracts text and discards all inner tags
                #     p.clear()  # Remove all the children of <p>
                #     p.append(text_only)  # Insert the clean text back into the <p>
                #     del p['class']

                # Create a new blockquote element
                # new_blockquote = soup.new_tag('blockquote')

                # Find and process the first type of p tags
                # quote_text = ""
                

                # Find and process the second type of p tags
                caption_text = ""
                for p in content_div.find_all('p', class_='цитата-підпис'):
                    text_only = p.get_text()  # Extracts text and discards all inner tags
                    caption_text += '\n\n' + text_only
                    # p.string = caption_text
                    # p.name = 'blockquote'
                    p.decompose()  # Remove the original tag

                for p in content_div.find_all('p', class_='Цитата-1-й'):
                    text_only = p.get_text()  # Extracts text and discards all inner tags
                    # quote_text += '\n' + text_only + '\n'  # Append a newline for separation
                    p.append(caption_text)
                    p.name = 'blockquote'
                    # p.decompose()  # Remove the original tag

                # Append combined texts to the new blockquote
                # new_blockquote.append(quote_text.strip() + '\n' + caption_text.strip())

                # Add the new blockquote to the content div
                # content_div.append(new_blockquote)
                
                for p in content_div.find_all('p'):
                    # p.unwrap()
                    text_only = p.get_text()  # Extracts text and discards all inner tags
                    p.clear()  # Remove all the children of <p>
                    p.append(text_only)  # Insert the clean text back into the <p>
                    p.unwrap()
                
                # Extract date for filename
                date_tag = content_div.find('b')
                if date_tag:
                    date_text = date_tag.text.strip()
                    mm_dd_date, original_date = convert_to_mm_dd_format(date_text)
                    
                    if mm_dd_date:
                        filename = f"{mm_dd_date} ({original_date}).txt"
                        filepath = os.path.join(output_dir, filename)
                        
                        # Write the HTML content to a file
                        # Write the HTML content to a file
                        with open(filepath, 'w', encoding='utf-8') as file:
                            # Initialize an empty string to collect all content
                            full_content = ""
                            
                            # Collect all children content into one string, appending a newline after each
                            for child in content_div.children:
                                # Strip each child content of trailing whitespace and newlines before adding a single newline
                                child_content = str(child).rstrip()  # Remove only trailing whitespace and newlines
                                full_content += child_content + '\n'  # Append a single newline after each child's content
                            
                            # Strip leading whitespace from the entire collected content block
                            # This will not remove the single newlines added intentionally at the end of each child's content
                            full_content = full_content.strip()  # Remove only leading whitespace

                            # Write the cleaned content to the file
                            file.write(full_content)


                        print(f"Saved: {filepath}")
                    else:
                        print(f"Invalid date format found in {item.file_name}")
                else:
                    print(f"Date not found in content division")
            else:
                print(f"Content division not found in {item.file_name}")

if __name__ == "__main__":
    # Path to the EPUB file
    epub_path = 'book/stoitsyzm-na-kozhen-den-366.epub'
    # Output directory to save the text files
    output_dir = 'daily_articles/stoic'
    
    # Extract content and save to text files
    extract_and_save_content(epub_path, output_dir)

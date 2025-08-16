import os
import asyncio
from telegram import Bot
# from telegram.utils.request import Request

async def send_message_to_telegram(bot_token, chat_id, message_text):
    """Send a message to a Telegram chat specified by chat_id."""
    # request = Request(con_pool_size=8)
    bot = Bot(token=bot_token)
    await bot.send_message(chat_id=chat_id, text=message_text, parse_mode='HTML')

def read_file_content(file_path):
    """Read the content of a file."""
    if not os.path.exists(file_path):
        print("File does not exist.")
        return None
    with open(file_path, 'r', encoding='utf-8') as file:
        return file.read()

def main():
    bot_token = 'token'  # Replace with your Telegram bot's token
    chat_id = 'chat_id'  # Replace with your chat ID or channel ID
    file_path = 'daily_articles/11-05 (5 листопада).txt'  # Path to the file you want to send

    # Read the content from the file
    content = read_file_content(file_path)
    if content:
        # Send the content as an HTML message to your Telegram chat
        # Create the asyncio event loop
        loop = asyncio.get_event_loop()
        # Run the send_message coroutine in the event loop
        loop.run_until_complete(send_message_to_telegram(bot_token, chat_id, content))
        # Close the loop
        loop.close()
    else:
        print("No content to send.")

if __name__ == "__main__":
    main()

import asyncio
import os
import boto3
import logging
import json
from datetime import datetime
from telegram import Bot
from telegram.error import TelegramError

# Constants for attribute keys
IS_SUBSCRIBED_TO_KEY = 'IsSubscribedTo'
IS_SUBSCRIBED_TO_STOIC_KEY = 'IsSubscribedToStoic'
IS_SUBSCRIBED_TO_PARENT_KEY = 'IsSubscribedToParent'

TELEGRAM_TOKEN_KEY = 'TELEGRAM_TOKEN'
CHAT_ID_KEY = 'ChatId'
TABLE_NAME = 'UserPreferences'
BUCKET_NAME = 'daily-motivation-messages'
S3_PREFIX_STOIC = 'stoic/'
S3_PREFIX_PARENT = 'parent/'

STOIC_EMOJI = '📖'
PARENT_EMOJI = '👶🏻'

# Create a boto3 client for DynamoDB and S3
dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')

# Bot Configs
bot_token = os.getenv(TELEGRAM_TOKEN_KEY)
bot = Bot(token=bot_token)

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)  # Set to DEBUG to capture all types of logs

table = dynamodb.Table(TABLE_NAME)  # DynamoDB table name

def get_filename_with_cyrillic_month():
    months_uk = {
        '01': 'січня', '02': 'лютого', '03': 'березня', '04': 'квітня',
        '05': 'травня', '06': 'червня', '07': 'липня', '08': 'серпня',
        '09': 'вересня', '10': 'жовтня', '11': 'листопада', '12': 'грудня'
    }
    today = datetime.now()
    day = today.strftime('%d').lstrip('0')
    day_with_leading_zero = today.strftime('%d')
    month_number = today.strftime('%m')
    month_name = months_uk[month_number]
    filename = f"{month_number}-{day_with_leading_zero} ({day} {month_name}).txt"
    return filename.lower()

async def fetch_subscribed_users():
    # Fetch all users with their subscription status for stoic and parent articles
    response = table.scan(
        ProjectionExpression=f"{CHAT_ID_KEY}, {IS_SUBSCRIBED_TO_STOIC_KEY}, {IS_SUBSCRIBED_TO_PARENT_KEY}"
    )
    return [
        (
            item[CHAT_ID_KEY],
            [
                S3_PREFIX_STOIC if item.get(IS_SUBSCRIBED_TO_STOIC_KEY, False) else None,
                S3_PREFIX_PARENT if item.get(IS_SUBSCRIBED_TO_PARENT_KEY, False) else None
            ]
        )
        for item in response['Items']
        if item.get(IS_SUBSCRIBED_TO_STOIC_KEY, False) or item.get(IS_SUBSCRIBED_TO_PARENT_KEY, False)
    ]


async def send_message():
    global bot

    filename = get_filename_with_cyrillic_month()
    logger.info("Filename to search - " + filename)

    # Assume fetch_subscribed_users returns a list of tuples (user_id, list of prefixes)
    subscribed_users = await fetch_subscribed_users()

    for user_id, prefixes in subscribed_users:
        for prefix in filter(None, prefixes):  # This filters out any None values in the list of prefixes
            try:
                # Define the emoji to prepend
                emoji_to_use = STOIC_EMOJI if prefix == S3_PREFIX_STOIC else PARENT_EMOJI

                # Construct the full S3 key for the file
                key = f"{prefix}{filename}"
                response = s3_client.get_object(Bucket=BUCKET_NAME, Key=key)
                message = emoji_to_use + " " + response['Body'].read().decode('utf-8')
                
                logger.info(f"Sending article with {prefix} type...")

                # Send the message using Telegram Bot
                await bot.send_message(chat_id=user_id, text=message, parse_mode='HTML')
            except Exception as e:
                logger.error(f"Failed to retrieve/send file for {user_id} with prefix {prefix}: {e}")



def lambda_handler(event, context):
    asyncio.run(send_message())
    return {
        'statusCode': 200,
        'body': 'Message sent successfully'
    }

def main():
    loop = asyncio.get_event_loop()
    loop.run_until_complete(send_message())
    loop.close()

if __name__ == '__main__':
    main()

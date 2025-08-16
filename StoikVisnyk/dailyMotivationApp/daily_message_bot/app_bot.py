import os
import logging
import json
import asyncio
from datetime import datetime
from telegram import Update, Bot
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes, Updater

# Initialize DynamoDB client
import boto3

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
S3_WELCOME_TEXT_FILE = 'message_start.txt'

STOIC_EMOJI = '📖'
PARENT_EMOJI = '👶🏻'

# Configure logger
logger = logging.getLogger()
logger.setLevel(logging.DEBUG)  # Set to DEBUG to capture all types of logs

dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')
table = dynamodb.Table(TABLE_NAME)
my_queue = asyncio.Queue()

# Bot Configs
bot_token = os.getenv(TELEGRAM_TOKEN_KEY)
bot = Bot(token=bot_token)

# Create the Application and pass it your bot's token.
application = None

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

async def send_message_with_article(bot, chat_id, prefix):
    # Define the emoji to prepend
    emoji_to_use = STOIC_EMOJI if prefix == S3_PREFIX_STOIC else PARENT_EMOJI

    filename = get_filename_with_cyrillic_month()
    logger.info("Filename to search - " + filename)
    try:
        response = s3_client.get_object(Bucket=BUCKET_NAME, Key=prefix + filename)
        # Read the message content and prepend the emoji with a newline
        message = emoji_to_use + " " + response['Body'].read().decode('utf-8')
        await bot.send_message(chat_id=chat_id, text=message, parse_mode='HTML')
    except Exception as e:
        logger.error(f"Failed to retrieve/send file with prefix {prefix}: {e}")
        raise Exception(f"Failed to retrieve/send file with prefix {prefix}: {e}")


def extract_user_or_chat_info(update):
    """Extracts username or chat name from the update object based on chat type."""
    chat_type = update.effective_chat.type
    if chat_type == 'private':
        # Extract user's first and last name for a private chat
        first_name = update.effective_user.first_name
        last_name = update.effective_user.last_name or ''  # Last name might not be present
        return first_name + ' ' + last_name if last_name else first_name, None
    else:
        # Extract chat title for groups and channels
        return None, update.effective_chat.title


async def unsubscribe(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    # Update the database to set IsSubscribed to False
    table.update_item(
        Key={CHAT_ID_KEY : str(chat_id)},
        UpdateExpression=f'SET {IS_SUBSCRIBED_TO_STOIC_KEY} = :val, {IS_SUBSCRIBED_TO_PARENT_KEY} = :val',
        ExpressionAttributeValues={':val': False}
    )
    await context.bot.send_message(chat_id=chat_id, text='Тепер ви не будете отримувати статті провісника :(')

async def subscribe_stoic(update, context):
    """Toggle subscription to stoic articles."""
    chat_id = update.effective_chat.id
    user_name, chat_name = extract_user_or_chat_info(update)

    # Toggle subscription status and pass relevant info
    response = toggle_subscription(chat_id, 'stoic', user_name, chat_name)
    action = 'підписані на' if response else 'відписані від'
    
    # Prepare response message
    if user_name:
        message = f"Тепер ви {action} статті стоїка {STOIC_EMOJI}!"
    else:
        message = f"Тепер користувачі цього чату {action} статті стоїка {STOIC_EMOJI}!"

    await context.bot.send_message(chat_id=chat_id, text=message)
    
    if response:
        await send_message_with_article(context.bot, chat_id, S3_PREFIX_STOIC)


async def subscribe_parent(update, context):
    """Toggle subscription to parent articles."""
    chat_id = update.effective_chat.id
    user_name, chat_name = extract_user_or_chat_info(update)

    # Toggle subscription status and pass relevant info
    response = toggle_subscription(chat_id, 'parent', user_name, chat_name)
    action = 'підписані на' if response else 'відписані від'
    
    # Prepare response message
    if user_name:
        message = f"Тепер ви {action} статті про батьківство {PARENT_EMOJI}!"
    else:
        message = f"Тепер користувачі цього чату {action} статті про батьківство {PARENT_EMOJI}!"

    await context.bot.send_message(chat_id=chat_id, text=message)

    if response:
        await send_message_with_article(context.bot, chat_id, S3_PREFIX_PARENT)


def toggle_subscription(user_id, article_type, username=None, chatname=None):
    """Toggle the subscription status in the DynamoDB."""
    attr_name = f'{IS_SUBSCRIBED_TO_KEY}{article_type.capitalize()}'
    # Retrieve current subscription status
    current_data = table.get_item(Key={CHAT_ID_KEY : str(user_id)})
    current_status = current_data.get('Item', {}).get(attr_name, False)
    new_status = not current_status

    update_expression = f"SET ChatName = :chatName, {attr_name} = :val"
    expression_attribute_values = {':val': new_status, ':chatName': ''}
    
    if username:
        expression_attribute_values[':chatName'] = username
    elif chatname:
        expression_attribute_values[':chatName'] = chatname

    # Update the subscription status
    table.update_item(
        Key={CHAT_ID_KEY: str(user_id)},
        UpdateExpression=update_expression,
        ExpressionAttributeValues=expression_attribute_values
    )
    return new_status

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    try:
        logger.debug("Update with /start command")
        
        # Get the welcome message from S3
        welcome_message = get_welcome_message()
        
        """Sends a message when the command /start is issued."""
        await context.bot.send_message(chat_id=update.effective_chat.id, text=welcome_message)
    except Exception as e:
        logger.error(e)

def configure_bot():
    global application  # Declare that we'll use the global variable
    if application:
        logger.debug("Application already configured, skipping configuration")
        return
    
    logger.debug("Configuring bot...")

    # Create the Application and pass it your bot's token.
    application = ApplicationBuilder().token(bot_token).build()

    # Add handlers for commands
    application.add_handler(CommandHandler("start", start))
    application.add_handler(CommandHandler("stoic", subscribe_stoic))
    application.add_handler(CommandHandler("parent", subscribe_parent))
    application.add_handler(CommandHandler("unsubscribe_from_all", unsubscribe))
    
    logger.debug("Configured.")

async def process_update(application, update_json):
    """Process the incoming update."""

    logger.debug("Initializing application...")
    await application.initialize()
    logger.debug("Handle update...")
    update = Update.de_json(update_json, application.bot)
    await application.process_update(update)

def get_welcome_message():
    # Create a boto3 client for S3
    global s3_client, bucket_name
    object_key = 'message_start.txt'

    try:
        # Fetch the welcome message from S3
        response = s3_client.get_object(Bucket=BUCKET_NAME, Key=object_key)
        # Read the content of the file
        message_content = response['Body'].read().decode('utf-8')
        return message_content
    except Exception as e:
        print(f"Failed to retrieve the welcome message: {e}")
        # Return a default message in case of an error
        return "Welcome to our Telegram bot! Type /help to get started."
    
def lambda_handler(event, context):
    print(event)
    try:
        configure_bot()
        update = event.get('body')
        if(update):
            # Process the incoming update from Telegram webhook
            body=json.loads(event['body'])
            print(body)

            logger.debug("Starting loop...")
            loop = asyncio.get_event_loop()
            loop.run_until_complete(process_update(application, body))
            logger.debug("Loop ended!")

        else:
            logger.warn("Event is not json")

        return {
            'statusCode': 200,
            'body': json.dumps('Handled the update v16')
        }
    
    except Exception as e:
        logger.error("Error in lambda_handler: %s", str(e))
        return {
            'statusCode': 500,
            'body': '[BotLambda]: Internal Server Error. ' + str(e)
        }
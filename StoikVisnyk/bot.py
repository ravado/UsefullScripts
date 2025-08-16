from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes, CallbackContext
import datetime

async def hello(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(f'Hello {update.effective_user.first_name}')

async def send_daily_message(context: CallbackContext) -> None:
    message_text = "Your daily message!"
    for chat_id in USER_IDS:
        try:
            await context.bot.send_message(chat_id=chat_id, text=message_text)
        except Exception as e:
            print(f"Failed to send message to {chat_id}: {str(e)}")

async def setup_daily_messages(app):
    # Schedule the daily message at a specific time (e.g., every day at 8:00 AM)
    time = datetime.time(hour=8, minute=0, second=0)
    app.job_queue.run_daily(send_daily_message, time, name="daily_message_job")

async def main():
    app = ApplicationBuilder().token(TOKEN).build()

    # Setup daily messages when the bot starts
    await setup_daily_messages(app)

    # Start the bot
    app.run_polling()

if __name__ == '__main__':
    import asyncio
    asyncio.run(main())

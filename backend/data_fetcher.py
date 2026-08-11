import yfinance as yf

def get_historical_gold_data(days=365):
    """Fetches historical gold price data (GC=F)."""
    # Use history to avoid multi-index downloading issues
    ticker = yf.Ticker("GC=F")
    # Determine valid period string based on days
    period = "1y"
    if days <= 5:
        period = "5d"
    elif days <= 30:
        period = "1mo"
    elif days <= 90:
        period = "3mo"
    elif days <= 180:
        period = "6mo"
    elif days <= 365:
        period = "1y"
    elif days <= 730:
        period = "2y"
    else:
        period = "5y"
        
    data = ticker.history(period=period)
    # We may get more days than requested (trading days vs calendar days)
    # Returning the tail ensures we get the most recent 'days' trading days.
    return data.tail(days)

def get_current_gold_price():
    """Fetches the latest available gold price."""
    ticker = yf.Ticker("GC=F")
    data = ticker.history(period="1d")
    if data.empty:
        return None
    return data['Close'].iloc[-1]

def format_credits(value, decimals=2):
    if value is None:
        return "0.00"
    return f"{value:,.{decimals}f}"


def format_usd(value, decimals=2):
    if value is None:
        return "$0.00"
    return f"${value:,.{decimals}f}"


def format_number(value):
    if value is None:
        return "0"
    return f"{value:,.0f}"


def format_pct(value, decimals=1):
    if value is None:
        return "N/A"
    return f"{value * 100:,.{decimals}f}%"

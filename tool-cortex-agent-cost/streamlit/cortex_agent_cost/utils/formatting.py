def format_credits(value):
    if value is None:
        return "0.00"
    return f"{value:,.2f}"


def format_usd(value):
    if value is None:
        return "$0.00"
    return f"${value:,.2f}"


def format_tokens(value):
    if value is None:
        return "0"
    if value >= 1_000_000:
        return f"{value / 1_000_000:,.1f}M"
    if value >= 1_000:
        return f"{value / 1_000:,.1f}K"
    return f"{value:,.0f}"


def format_latency(ms):
    if ms is None:
        return "N/A"
    if ms >= 1000:
        return f"{ms / 1000:,.1f}s"
    return f"{ms:,.0f}ms"


def format_pct(value):
    if value is None:
        return "0.0%"
    return f"{value:.1f}%"

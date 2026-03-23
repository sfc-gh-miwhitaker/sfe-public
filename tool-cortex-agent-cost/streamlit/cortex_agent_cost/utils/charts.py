import plotly.express as px
import plotly.graph_objects as go


COLORS = {
    "primary": "#29B5E8",
    "secondary": "#7B2D8E",
    "success": "#2ECC71",
    "warning": "#F39C12",
    "danger": "#E74C3C",
    "muted": "#888888",
}

SERVICE_COLORS = {
    "Cortex Agent": COLORS["primary"],
    "Snowflake Intelligence": COLORS["secondary"],
}


def _apply_layout(fig, height=350):
    fig.update_layout(
        height=height,
        margin=dict(l=0, r=0, t=30, b=0),
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
    )
    return fig


def daily_credits_area(df, x="USAGE_DATE", y="DAILY_CREDITS", color=None, color_map=None):
    if color:
        fig = px.area(df, x=x, y=y, color=color,
                      color_discrete_map=color_map or {},
                      labels={x: "Date", y: "Credits"})
    else:
        fig = px.area(df, x=x, y=y,
                      labels={x: "Date", y: "Credits"})
        fig.update_traces(line_color=COLORS["primary"],
                          fillcolor="rgba(41,181,232,0.2)")
    return _apply_layout(fig)


def credits_bar(df, x, y, color=None, color_map=None, barmode="stack"):
    fig = px.bar(df, x=x, y=y, color=color,
                 color_discrete_map=color_map or {},
                 barmode=barmode,
                 labels={x: x.replace("_", " ").title(), y: "Credits"})
    return _apply_layout(fig)


def donut_chart(df, values, names, color_map=None, title=None):
    fig = px.pie(df, values=values, names=names,
                 color=names,
                 color_discrete_map=color_map or {},
                 hole=0.45, title=title)
    fig.update_traces(textposition="inside", textinfo="percent+label")
    return _apply_layout(fig, height=300)


def horizontal_bar(df, x, y, color=None, color_map=None):
    fig = px.bar(df, x=x, y=y, orientation="h",
                 color=color,
                 color_discrete_map=color_map or {},
                 labels={x: "Credits", y: ""})
    fig.update_layout(yaxis=dict(autorange="reversed"))
    return _apply_layout(fig, height=max(250, len(df) * 35))

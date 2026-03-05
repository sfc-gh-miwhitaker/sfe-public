import plotly.express as px
import plotly.graph_objects as go


COLORS = [
    "#29B5E8", "#71D6FF", "#FF6B6B", "#4ECDC4",
    "#45B7D1", "#96CEB4", "#FFEAA7", "#DDA0DD",
    "#98D8C8", "#F7DC6F", "#BB8FCE", "#85C1E9",
]


def daily_credits_chart(df, height=400):
    fig = px.area(
        df,
        x="USAGE_DATE",
        y="TOTAL_CREDITS",
        color="SERVICE_TYPE",
        color_discrete_sequence=COLORS,
        labels={"USAGE_DATE": "Date", "TOTAL_CREDITS": "Credits", "SERVICE_TYPE": "Service"},
    )
    fig.update_layout(
        height=height,
        margin=dict(l=0, r=0, t=30, b=0),
        legend=dict(orientation="h", yanchor="bottom", y=1.02),
    )
    return fig


def service_pie_chart(df, height=350):
    fig = px.pie(
        df,
        values="TOTAL_CREDITS",
        names="SERVICE_TYPE",
        color_discrete_sequence=COLORS,
        hole=0.4,
    )
    fig.update_layout(
        height=height,
        margin=dict(l=0, r=0, t=30, b=0),
    )
    return fig


def user_bar_chart(df, height=400, top_n=15):
    top = df.head(top_n)
    fig = px.bar(
        top,
        x="TOTAL_CREDITS",
        y="USER_NAME",
        color="SERVICE_TYPE",
        orientation="h",
        color_discrete_sequence=COLORS,
        labels={"TOTAL_CREDITS": "Credits", "USER_NAME": "User", "SERVICE_TYPE": "Service"},
    )
    fig.update_layout(
        height=height,
        margin=dict(l=0, r=0, t=30, b=0),
        yaxis=dict(autorange="reversed"),
    )
    return fig


def sparkline(values, height=60, width=200):
    fig = go.Figure(go.Scatter(
        y=values,
        mode="lines",
        line=dict(color="#29B5E8", width=2),
        fill="tozeroy",
        fillcolor="rgba(41, 181, 232, 0.1)",
    ))
    fig.update_layout(
        height=height,
        width=width,
        margin=dict(l=0, r=0, t=0, b=0),
        xaxis=dict(visible=False),
        yaxis=dict(visible=False),
        showlegend=False,
    )
    return fig

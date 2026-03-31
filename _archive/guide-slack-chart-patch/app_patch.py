"""
Patch for app.py

Add chart rendering and upload to the display_agent_response function.
"""

# =============================================================================
# ADD IMPORT AT TOP OF app.py
# =============================================================================

"""
Add this import near the top of the file with other imports:

from chart_renderer import ChartRenderer, upload_chart_to_slack
"""


# =============================================================================
# MODIFY display_agent_response FUNCTION
# =============================================================================

"""
Replace the display_agent_response function with this version:
"""


def display_agent_response(content, say, app=None, channel_id=None):
    """Enhanced response display with SQL execution, charts, and improved formatting."""
    try:

        # Display the final agent response text
        if content.get('text'):
            formatted_text = format_text_for_slack(content['text'])
            say(
                text="🎯 Final Response",
                    blocks=[
                        {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*🎯 Snowflake Cortex Agent Response:*\n{formatted_text}"
                        }
                    }
                ]
            )

        # Store verification and SQL info for planning section
        if content.get('verification_info') or content.get('verified_query_used'):
            CORTEX_APP.verification_info = content.get('verification_info', {})
            CORTEX_APP.verified_query_used = content.get('verified_query_used', False)

        if content.get('sql_queries'):
            CORTEX_APP.sql_queries = content['sql_queries']

        # =================================================================
        # NEW: Render and upload charts
        # =================================================================
        chart_specs = content.get('chart_specs', [])
        if chart_specs and app and channel_id:
            try:
                from chart_renderer import ChartRenderer, upload_chart_to_slack
                renderer = ChartRenderer()

                for i, spec in enumerate(chart_specs):
                    print(f"📊 Rendering chart {i + 1} of {len(chart_specs)}...")

                    png_data = renderer.render_vegalite_to_png(spec)
                    if png_data:
                        title = spec.get('title', {})
                        if isinstance(title, dict):
                            chart_title = title.get('text', f'Chart {i + 1}')
                        elif isinstance(title, str):
                            chart_title = title
                        else:
                            chart_title = f'Chart {i + 1}'

                        file_id = upload_chart_to_slack(
                            slack_client=app.client,
                            channel_id=channel_id,
                            png_data=png_data,
                            title=chart_title,
                            initial_comment=f"📊 *{chart_title}*" if chart_title != f'Chart {i + 1}' else None
                        )

                        if file_id:
                            print(f"✅ Chart uploaded successfully (file_id: {file_id})")
                        else:
                            print(f"❌ Failed to upload chart {i + 1}")
                            say(
                                text="⚠️ Chart rendering issue",
                                blocks=[{
                                    "type": "section",
                                    "text": {
                                        "type": "mrkdwn",
                                        "text": f"⚠️ _Chart {i + 1} could not be uploaded. The data is included in the response above._"
                                    }
                                }]
                            )
                    else:
                        print(f"❌ Failed to render chart {i + 1}")
                        say(
                            text="⚠️ Chart rendering issue",
                            blocks=[{
                                "type": "section",
                                "text": {
                                    "type": "mrkdwn",
                                    "text": f"⚠️ _Chart {i + 1} could not be rendered. Install vl-convert-python for chart support._"
                                }
                            }]
                        )

            except ImportError:
                print("⚠️ chart_renderer module not available - charts will not be displayed")
                if chart_specs:
                    say(
                        text="⚠️ Charts available but renderer not installed",
                        blocks=[{
                            "type": "section",
                            "text": {
                                "type": "mrkdwn",
                                "text": "⚠️ _This response includes charts, but the chart renderer is not installed. Run `pip install vl-convert-python` to enable chart visualization._"
                            }
                        }]
                    )
            except Exception as chart_error:
                print(f"❌ Error rendering charts: {chart_error}")
        # =================================================================

        # Display citations if present
        if content.get('citations') and content['citations']:
            formatted_citations = format_text_for_slack(content['citations'])
            say(
                text="📚 Citations",
                blocks=[
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*📚 Citations:*\n_{formatted_citations}_"
                        }
                    }
                ]
            )

        # Display suggestions if present
        if content.get('suggestions'):
            formatted_suggestions = [format_text_for_slack(suggestion) for suggestion in content['suggestions'][:3]]
            suggestions_text = "\n".join(f"• {suggestion}" for suggestion in formatted_suggestions)
            say(
                text="💡 Suggestions",
                blocks=[
                    {
                        "type": "section",
                        "text": {
                            "type": "mrkdwn",
                            "text": f"*💡 Follow-up Suggestions:*\n{suggestions_text}"
                        }
                    }
                ]
            )

    except Exception as e:
        error_info = f"{type(e).__name__} at line {e.__traceback__.tb_lineno} of {__file__}: {e}"
        print(f"❌ Error in display_agent_response: {error_info}")
        say(
            text="❌ Display error",
            blocks=[{
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"❌ *Error displaying response*\n```{error_info}```"
                }
            }]
        )


# =============================================================================
# UPDATE CALLS TO display_agent_response
# =============================================================================

"""
In handle_message_event function, update the call to display_agent_response:

FROM:
    display_agent_response(response, say)

TO:
    display_agent_response(response, say, app=app, channel_id=event.get('channel'))


In handle_message_events function, update similarly:

FROM:
    display_agent_response(response, say)

TO:
    display_agent_response(response, say, app=app, channel_id=body['event']['channel'])
"""

"""
Patch for cortex_response_parser.py

Add these methods to the existing ToolResult and CortexResponse classes,
and update the extract_summary method.
"""

# =============================================================================
# ADD TO ToolResult CLASS (after existing @property methods)
# =============================================================================

"""
Add this property to the ToolResult class:

    @property
    def chart_spec(self) -> Optional[Dict[str, Any]]:
        '''Extract Vega-Lite chart specification from tool results.'''
        for item in self.content:
            if isinstance(item, dict):
                # Check direct json content
                if 'json' in item:
                    json_data = item['json']
                    # Look for chart/visualization in various locations
                    if 'chart' in json_data:
                        return json_data['chart']
                    if 'visualization' in json_data:
                        return json_data['visualization']
                    if 'vega_lite' in json_data:
                        return json_data['vega_lite']
                    if 'vegaLite' in json_data:
                        return json_data['vegaLite']
                    # Check for nested results
                    if 'results' in json_data and isinstance(json_data['results'], dict):
                        results = json_data['results']
                        if 'chart' in results:
                            return results['chart']
                        if 'visualization' in results:
                            return results['visualization']
                # Check for chart at top level of item
                if 'chart' in item:
                    return item['chart']
                if 'visualization' in item:
                    return item['visualization']
        return None
"""


# =============================================================================
# ADD TO CortexResponse CLASS (after existing @property methods)
# =============================================================================

"""
Add this property to the CortexResponse class:

    @property
    def chart_specs(self) -> List[Dict[str, Any]]:
        '''Extract all chart specifications from tool results.'''
        charts = []
        for message in self.messages:
            for tool_result in message.tool_results:
                chart = tool_result.chart_spec
                if chart:
                    charts.append(chart)
        return charts
"""


# =============================================================================
# MODIFY extract_summary METHOD in CortexResponseParser class
# =============================================================================

"""
Update the extract_summary method to include chart_specs.
Replace the return statement with:

        return {
            'text': response.final_text,
            'sql_queries': response.sql_queries,
            'citations': response.citations,
            'suggestions': [s.text for s in response.suggestions],
            'tool_uses': len([tool for msg in response.messages for tool in msg.tool_uses]),
            'search_results_count': len(response.search_results),
            'verification_info': verification_info,
            'verified_query_used': verified_query_used,
            'planning_updates': planning_updates,
            'chart_specs': response.chart_specs,  # ADD THIS LINE
        }
"""


# =============================================================================
# COMPLETE REPLACEMENT CODE (copy-paste ready)
# =============================================================================

# If you prefer, here's the complete updated code for the relevant sections:

TOOL_RESULT_CHART_PROPERTY = '''
    @property
    def chart_spec(self) -> Optional[Dict[str, Any]]:
        """Extract Vega-Lite chart specification from tool results."""
        for item in self.content:
            if isinstance(item, dict):
                if 'json' in item:
                    json_data = item['json']
                    for key in ['chart', 'visualization', 'vega_lite', 'vegaLite']:
                        if key in json_data:
                            return json_data[key]
                    if 'results' in json_data and isinstance(json_data['results'], dict):
                        results = json_data['results']
                        for key in ['chart', 'visualization']:
                            if key in results:
                                return results[key]
                for key in ['chart', 'visualization']:
                    if key in item:
                        return item[key]
        return None
'''

CORTEX_RESPONSE_CHARTS_PROPERTY = '''
    @property
    def chart_specs(self) -> List[Dict[str, Any]]:
        """Extract all chart specifications from tool results."""
        charts = []
        for message in self.messages:
            for tool_result in message.tool_results:
                chart = tool_result.chart_spec
                if chart:
                    charts.append(chart)
        return charts
'''

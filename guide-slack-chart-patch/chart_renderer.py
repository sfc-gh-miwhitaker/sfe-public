"""
Chart Renderer for Cortex Agent + Slack Integration

Renders Vega-Lite chart specifications to PNG images for Slack display.
"""

import io
import json
from typing import Optional, Dict, Any, Union

try:
    import vl_convert as vlc
    VL_CONVERT_AVAILABLE = True
except ImportError:
    VL_CONVERT_AVAILABLE = False
    print("WARNING: vl-convert-python not installed. Charts will not render.")
    print("Install with: pip install vl-convert-python")


class ChartRenderer:
    """Renders Vega-Lite specifications to PNG images."""

    def __init__(self, scale: float = 2.0, default_width: int = 600, default_height: int = 400):
        """
        Initialize the chart renderer.

        Args:
            scale: Scale factor for output resolution (2.0 = retina)
            default_width: Default chart width if not specified in spec
            default_height: Default chart height if not specified in spec
        """
        self.scale = scale
        self.default_width = default_width
        self.default_height = default_height

    def render_vegalite_to_png(self, spec: Union[str, Dict[str, Any]]) -> Optional[bytes]:
        """
        Render a Vega-Lite specification to PNG bytes.

        Args:
            spec: Vega-Lite specification as dict or JSON string

        Returns:
            PNG image as bytes, or None if rendering fails
        """
        if not VL_CONVERT_AVAILABLE:
            print("ERROR: vl-convert-python not available")
            return None

        try:
            if isinstance(spec, str):
                spec = json.loads(spec)

            if not isinstance(spec, dict):
                print(f"ERROR: Invalid spec type: {type(spec)}")
                return None

            spec = self._normalize_spec(spec)
            spec_json = json.dumps(spec)

            png_data = vlc.vegalite_to_png(
                spec_json,
                scale=self.scale
            )

            return png_data

        except json.JSONDecodeError as e:
            print(f"ERROR: Invalid JSON in chart spec: {e}")
            return None
        except Exception as e:
            print(f"ERROR: Failed to render chart: {e}")
            return None

    def _normalize_spec(self, spec: Dict[str, Any]) -> Dict[str, Any]:
        """
        Normalize a Vega-Lite spec with defaults.

        Args:
            spec: Original Vega-Lite specification

        Returns:
            Normalized specification with defaults applied
        """
        normalized = spec.copy()

        if "$schema" not in normalized:
            normalized["$schema"] = "https://vega.github.io/schema/vega-lite/v5.json"

        if "width" not in normalized:
            normalized["width"] = self.default_width
        if "height" not in normalized:
            normalized["height"] = self.default_height

        if "config" not in normalized:
            normalized["config"] = {}

        if "background" not in normalized["config"]:
            normalized["config"]["background"] = "white"

        return normalized

    def render_to_file(self, spec: Union[str, Dict[str, Any]], filepath: str) -> bool:
        """
        Render a Vega-Lite specification to a PNG file.

        Args:
            spec: Vega-Lite specification
            filepath: Output file path

        Returns:
            True if successful, False otherwise
        """
        png_data = self.render_vegalite_to_png(spec)
        if png_data is None:
            return False

        try:
            with open(filepath, 'wb') as f:
                f.write(png_data)
            return True
        except IOError as e:
            print(f"ERROR: Failed to write file: {e}")
            return False


def upload_chart_to_slack(
    slack_client,
    channel_id: str,
    png_data: bytes,
    title: str = "Chart",
    initial_comment: str = None
) -> Optional[str]:
    """
    Upload a chart image to Slack.

    Args:
        slack_client: Slack client instance (from slack_bolt App)
        channel_id: Slack channel ID
        png_data: PNG image bytes
        title: Title for the uploaded file
        initial_comment: Optional comment to add with the upload

    Returns:
        File ID if successful, None otherwise
    """
    try:
        response = slack_client.files_upload_v2(
            channel=channel_id,
            file=io.BytesIO(png_data),
            filename=f"{title.replace(' ', '_')}.png",
            title=title,
            initial_comment=initial_comment
        )

        if response.get("ok"):
            file_info = response.get("file", {})
            return file_info.get("id")
        else:
            print(f"ERROR: Slack upload failed: {response.get('error')}")
            return None

    except Exception as e:
        print(f"ERROR: Failed to upload to Slack: {e}")
        return None


_default_renderer = None

def get_renderer() -> ChartRenderer:
    """Get or create the default chart renderer."""
    global _default_renderer
    if _default_renderer is None:
        _default_renderer = ChartRenderer()
    return _default_renderer


def render_chart(spec: Union[str, Dict[str, Any]]) -> Optional[bytes]:
    """
    Convenience function to render a chart using the default renderer.

    Args:
        spec: Vega-Lite specification

    Returns:
        PNG bytes or None
    """
    return get_renderer().render_vegalite_to_png(spec)


if __name__ == "__main__":
    test_spec = {
        "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
        "data": {
            "values": [
                {"category": "A", "value": 28},
                {"category": "B", "value": 55},
                {"category": "C", "value": 43}
            ]
        },
        "mark": "bar",
        "encoding": {
            "x": {"field": "category", "type": "nominal"},
            "y": {"field": "value", "type": "quantitative"}
        }
    }

    renderer = ChartRenderer()
    png_data = renderer.render_vegalite_to_png(test_spec)

    if png_data:
        print(f"SUCCESS: Rendered chart ({len(png_data)} bytes)")
        renderer.render_to_file(test_spec, "test_chart.png")
        print("Saved to test_chart.png")
    else:
        print("FAILED: Could not render chart")

# Streamlit Brand Configurator -- Data Flow

```mermaid
flowchart TD
    subgraph sidebar [Sidebar Controls]
        Colors["Color Pickers<br/>primary, bg, text, link,<br/>border, sidebar"]
        Borders["Border Controls<br/>radius, widget borders"]
        Fonts["Font Selector<br/>built-in or Google Fonts"]
        Logo["Logo Inputs<br/>URL, icon, link"]
    end

    subgraph preview [Live Preview Pane]
        CSS["CSS Injection<br/>st.markdown(unsafe_allow_html)"]
        Widgets["Sample Widgets<br/>headings, metrics, buttons,<br/>tables, alerts, code"]
    end

    subgraph export [Export Tab]
        TOML["config.toml<br/>Generator"]
        PY["streamlit_app.py<br/>Boilerplate"]
        Guide["Setup<br/>Instructions"]
        DL["Download<br/>Buttons"]
    end

    Colors --> CSS
    Borders --> CSS
    Fonts --> CSS
    Logo --> CSS
    CSS --> Widgets

    Colors --> TOML
    Borders --> TOML
    Fonts --> TOML
    Logo --> PY
    TOML --> DL
    PY --> DL
    Guide --> DL
```

## Flow Summary

1. User adjusts controls in the sidebar (colors, borders, fonts, logo)
2. Each change triggers a CSS `<style>` injection into the main pane
3. The preview pane re-renders sample widgets with the new styles
4. On the Export tab, generators build `config.toml` and `streamlit_app.py` from the same state
5. User downloads files and applies them to their own Streamlit project

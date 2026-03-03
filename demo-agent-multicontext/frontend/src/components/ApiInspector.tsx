import { useState, useMemo } from 'react';
import type { AgentContext } from '../types';
import { buildPayloadPreview } from '../utils/buildAgentPayload';

interface ApiInspectorProps {
  context: AgentContext;
  draftMessage: string;
}

export function ApiInspector({ context, draftMessage }: ApiInspectorProps) {
  const [isExpanded, setIsExpanded] = useState(true);
  const [activeTab, setActiveTab] = useState<'full' | 'instructions' | 'tools'>('instructions');

  const preview = useMemo(
    () => buildPayloadPreview(context, draftMessage),
    [context, draftMessage],
  );

  const instructionsJson = JSON.stringify(
    (preview.body as Record<string, unknown>).instructions,
    null,
    2,
  );
  const toolsJson = JSON.stringify(
    {
      tools: (preview.body as Record<string, unknown>).tools,
      tool_resources: (preview.body as Record<string, unknown>).tool_resources,
    },
    null,
    2,
  );
  const fullJson = JSON.stringify(
    { endpoint: preview.endpoint, headers: preview.headers, body: preview.body },
    null,
    2,
  );

  const activeJson =
    activeTab === 'instructions' ? instructionsJson
    : activeTab === 'tools' ? toolsJson
    : fullJson;

  return (
    <div className="inspector-panel">
      <button className="inspector-toggle" onClick={() => setIsExpanded(!isExpanded)}>
        <span className="inspector-icon">{isExpanded ? '▼' : '▶'}</span>
        <span>API Request Inspector</span>
        <span className="inspector-endpoint">{preview.endpoint}</span>
      </button>

      {isExpanded && (
        <div className="inspector-body">
          <div className="inspector-tabs">
            <button
              className={`tab ${activeTab === 'instructions' ? 'active' : ''}`}
              onClick={() => setActiveTab('instructions')}
            >
              instructions
            </button>
            <button
              className={`tab ${activeTab === 'tools' ? 'active' : ''}`}
              onClick={() => setActiveTab('tools')}
            >
              tools
            </button>
            <button
              className={`tab ${activeTab === 'full' ? 'active' : ''}`}
              onClick={() => setActiveTab('full')}
            >
              full payload
            </button>
          </div>

          <div className="inspector-info">
            {activeTab === 'instructions' && (
              <p>
                This is what changes per request. The <code>system</code> field carries user identity
                and station branding. Switch the user type or station above to see it update live.
              </p>
            )}
            {activeTab === 'tools' && (
              <p>
                Tools available to the agent vary by authorization tier. Anonymous users
                only get Cortex Search. Authenticated users also get Cortex Analyst.
              </p>
            )}
            {activeTab === 'full' && (
              <p>
                The complete <code>POST /api/v2/cortex/agent:run</code> request body.
                No agent object needed -- everything is passed inline per request.
              </p>
            )}
          </div>

          {preview.headers['X-Snowflake-Role'] && (
            <div className="inspector-role-badge">
              X-Snowflake-Role: {preview.headers['X-Snowflake-Role']}
            </div>
          )}

          <pre className="inspector-json"><code>{activeJson}</code></pre>
        </div>
      )}
    </div>
  );
}

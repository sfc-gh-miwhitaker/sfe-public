import React, { useState } from 'react';
import './ConfigPanel.css';

const ConfigPanel = ({ config, onSave, onCancel }) => {
  const [formData, setFormData] = useState({
    account: config.account || '',
    user: config.user || '',
    database: config.database || '',
    schema: config.schema || '',
    agentName: config.agentName || ''
  });

  const [errors, setErrors] = useState({});

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: value
    }));

    // Clear error when user starts typing
    if (errors[name]) {
      setErrors(prev => ({
        ...prev,
        [name]: ''
      }));
    }
  };

  const validateForm = () => {
    const newErrors = {};

    if (!formData.account.trim()) {
      newErrors.account = 'Snowflake account is required';
    }

    if (!formData.user.trim()) {
      newErrors.user = 'Snowflake user is required';
    }

    if (!formData.database.trim()) {
      newErrors.database = 'Database name is required';
    }

    if (!formData.schema.trim()) {
      newErrors.schema = 'Schema name is required';
    }

    if (!formData.agentName.trim()) {
      newErrors.agentName = 'Agent name is required';
    }

    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = (e) => {
    e.preventDefault();

    if (validateForm()) {
      onSave(formData);
    }
  };

  return (
    <div className="config-panel">
      <div className="config-card">
        <h2>Configure Snowflake Connection</h2>
        <p className="config-description">
          Enter your Snowflake account details and Cortex Agent information. The backend proxy handles RSA key-pair authentication and never exposes the private key to the browser.
        </p>
        <div className="pat-info">
          <strong>🔐 Key-Pair Authentication:</strong> Managed server-side by the local backend proxy. Keep the private key in <code>.env.server.local</code>, not in the browser.
        </div>

        <form onSubmit={handleSubmit} className="config-form">
          <div className="form-group">
            <label htmlFor="account">Snowflake Account *</label>
            <input
              type="text"
              id="account"
              name="account"
              value={formData.account}
              onChange={handleChange}
              placeholder="e.g., xy12345.us-east-1"
              className={errors.account ? 'error' : ''}
            />
            {errors.account && <span className="error-message">{errors.account}</span>}
          </div>

          <div className="form-group">
            <label htmlFor="user">Snowflake User *</label>
            <input
              type="text"
              id="user"
              name="user"
              value={formData.user}
              onChange={handleChange}
              placeholder="e.g., DEMO_USER"
              className={errors.user ? 'error' : ''}
            />
            {errors.user && <span className="error-message">{errors.user}</span>}
          </div>

          <div className="form-group">
            <label htmlFor="database">Database *</label>
            <input
              type="text"
              id="database"
              name="database"
              value={formData.database}
              onChange={handleChange}
              placeholder="Database name"
              className={errors.database ? 'error' : ''}
            />
            {errors.database && <span className="error-message">{errors.database}</span>}
          </div>

          <div className="form-group">
            <label htmlFor="schema">Schema *</label>
            <input
              type="text"
              id="schema"
              name="schema"
              value={formData.schema}
              onChange={handleChange}
              placeholder="Schema name"
              className={errors.schema ? 'error' : ''}
            />
            {errors.schema && <span className="error-message">{errors.schema}</span>}
          </div>

          <div className="form-group">
            <label htmlFor="agentName">Agent Name *</label>
            <input
              type="text"
              id="agentName"
              name="agentName"
              value={formData.agentName}
              onChange={handleChange}
              placeholder="Cortex Agent name"
              className={errors.agentName ? 'error' : ''}
            />
            {errors.agentName && <span className="error-message">{errors.agentName}</span>}
          </div>

          <div className="form-actions">
            {onCancel && (
              <button type="button" className="cancel-button" onClick={onCancel}>
                Cancel
              </button>
            )}
            <button type="submit" className="save-button">
              Save Configuration
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default ConfigPanel;

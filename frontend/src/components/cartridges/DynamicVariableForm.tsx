import React, { useState, useEffect, useMemo } from 'react';
import { CartridgeVariable, CartridgeVariableGroup } from '@/types';

interface DynamicVariableFormProps {
  variables: CartridgeVariable[];
  groups?: CartridgeVariableGroup[];
  values: Record<string, string>;
  onChange: (values: Record<string, string>) => void;
  errors?: Record<string, string>;
  showAdvanced?: boolean;
}

export const DynamicVariableForm: React.FC<DynamicVariableFormProps> = ({
  variables,
  groups = [],
  values,
  onChange,
  errors = {},
  showAdvanced = false,
}) => {
  const [expandedGroups, setExpandedGroups] = useState<Record<string, boolean>>(() => {
    const initial: Record<string, boolean> = {};
    groups.forEach(g => {
      initial[g.id] = g.collapsed !== true;
    });
    return initial;
  });

  // Initialize values with defaults
  useEffect(() => {
    const newValues = { ...values };
    let hasChanges = false;
    
    variables.forEach(v => {
      if (!(v.envVariable in newValues) && v.default !== undefined) {
        newValues[v.envVariable] = String(v.default);
        hasChanges = true;
      }
    });
    
    if (hasChanges) {
      onChange(newValues);
    }
  }, [variables, values, onChange]);

  const handleChange = (envVar: string, value: string) => {
    onChange({
      ...values,
      [envVar]: value,
    });
  };

  // Group variables by their group_id
  const groupedVariables = useMemo(() => {
    const grouped: Record<string, CartridgeVariable[]> = {
      ungrouped: [],
    };
    
    groups.forEach(g => {
      grouped[g.id] = [];
    });
    
    variables.forEach(v => {
      // Skip hidden variables
      if (v.ui?.hidden) return;
      // Show user-editable variables, or all if showAdvanced is true
      if (!v.userEditable && !v.userViewable && !showAdvanced) return;
      
      const groupId = v.ui?.group || 'ungrouped';
      if (!grouped[groupId]) {
        grouped[groupId] = [];
      }
      grouped[groupId].push(v);
    });
    
    return grouped;
  }, [variables, groups, showAdvanced]);

  const toggleGroup = (groupId: string) => {
    setExpandedGroups(prev => ({
      ...prev,
      [groupId]: !prev[groupId],
    }));
  };

  const renderVariableInput = (variable: CartridgeVariable) => {
    const value = values[variable.envVariable] ?? String(variable.default ?? '');
    const error = errors[variable.envVariable];
    const ui = variable.ui;
    const component = ui?.component || 'text';
    
    const baseInputClasses = `
      w-full px-3 py-2 bg-panel-dark border rounded-lg text-white 
      focus:outline-none focus:ring-2 focus:ring-purple-500
      ${error ? 'border-red-500' : 'border-panel-border'}
      ${!variable.userEditable ? 'opacity-60' : ''}
    `;

    switch (component) {
      case 'select':
        return (
          <select
            value={value}
            onChange={(e) => handleChange(variable.envVariable, e.target.value)}
            disabled={!variable.userEditable}
            className={baseInputClasses}
          >
            {ui?.options?.map((opt) => (
              <option key={opt.value} value={opt.value}>
                {opt.label}
              </option>
            ))}
          </select>
        );

      case 'switch':
        return (
          <button
            type="button"
            onClick={() => handleChange(variable.envVariable, value === 'true' ? 'false' : 'true')}
            disabled={!variable.userEditable}
            className={`
              relative inline-flex h-6 w-11 items-center rounded-full transition-colors
              ${value === 'true' ? 'bg-purple-600' : 'bg-panel-border'}
              ${!variable.userEditable ? 'opacity-60 cursor-not-allowed' : 'cursor-pointer'}
            `}
          >
            <span
              className={`
                inline-block h-4 w-4 transform rounded-full bg-white transition-transform
                ${value === 'true' ? 'translate-x-6' : 'translate-x-1'}
              `}
            />
          </button>
        );

      case 'slider':
        const min = variable.validation?.min ?? 0;
        const max = variable.validation?.max ?? 100;
        const step = ui?.step ?? 1;
        const numValue = parseFloat(value) || min;
        
        return (
          <div className="flex items-center gap-4">
            <input
              type="range"
              min={min}
              max={max}
              step={step}
              value={numValue}
              onChange={(e) => handleChange(variable.envVariable, e.target.value)}
              disabled={!variable.userEditable}
              className="flex-1 h-2 bg-panel-border rounded-lg appearance-none cursor-pointer accent-purple-500"
            />
            <div className="flex items-center gap-1 min-w-[80px]">
              <input
                type="number"
                min={min}
                max={max}
                step={step}
                value={numValue}
                onChange={(e) => handleChange(variable.envVariable, e.target.value)}
                disabled={!variable.userEditable}
                className="w-16 px-2 py-1 bg-panel-dark border border-panel-border rounded text-white text-sm text-center"
              />
              {ui?.suffix && <span className="text-gray-400 text-sm">{ui.suffix}</span>}
            </div>
          </div>
        );

      case 'number':
        return (
          <div className="flex items-center gap-2">
            <input
              type="number"
              value={value}
              onChange={(e) => handleChange(variable.envVariable, e.target.value)}
              disabled={!variable.userEditable}
              min={variable.validation?.min ?? undefined}
              max={variable.validation?.max ?? undefined}
              step={ui?.step}
              className={baseInputClasses}
            />
            {ui?.suffix && <span className="text-gray-400">{ui.suffix}</span>}
          </div>
        );

      case 'password':
        return (
          <input
            type="password"
            value={value}
            onChange={(e) => handleChange(variable.envVariable, e.target.value)}
            disabled={!variable.userEditable}
            placeholder={ui?.placeholder}
            className={baseInputClasses}
          />
        );

      case 'textarea':
        return (
          <textarea
            value={value}
            onChange={(e) => handleChange(variable.envVariable, e.target.value)}
            disabled={!variable.userEditable}
            placeholder={ui?.placeholder}
            rows={4}
            className={baseInputClasses}
          />
        );

      case 'text':
      default:
        return (
          <div className="flex items-center gap-2">
            {ui?.prefix && <span className="text-gray-400">{ui.prefix}</span>}
            <input
              type="text"
              value={value}
              onChange={(e) => handleChange(variable.envVariable, e.target.value)}
              disabled={!variable.userEditable}
              placeholder={ui?.placeholder}
              className={baseInputClasses}
            />
            {ui?.suffix && <span className="text-gray-400">{ui.suffix}</span>}
          </div>
        );
    }
  };

  const renderVariable = (variable: CartridgeVariable) => {
    const error = errors[variable.envVariable];
    
    return (
      <div key={variable.envVariable} className="space-y-2">
        <div className="flex items-center justify-between">
          <label className="block text-sm font-medium text-gray-300">
            {variable.name}
            {variable.required && <span className="text-red-400 ml-1">*</span>}
          </label>
          {!variable.userEditable && (
            <span className="text-xs text-gray-500 bg-panel-dark px-2 py-0.5 rounded">
              System
            </span>
          )}
        </div>
        
        {variable.description && (
          <p className="text-xs text-gray-500">{variable.description}</p>
        )}
        
        {renderVariableInput(variable)}
        
        {error && (
          <p className="text-xs text-red-400">{error}</p>
        )}
        
        {variable.ui?.help && (
          <p className="text-xs text-gray-500">{variable.ui.help}</p>
        )}
      </div>
    );
  };

  const renderGroup = (group: CartridgeVariableGroup) => {
    const groupVars = groupedVariables[group.id] || [];
    if (groupVars.length === 0) return null;
    
    const isExpanded = expandedGroups[group.id] ?? true;
    
    return (
      <div key={group.id} className="border border-panel-border rounded-lg overflow-hidden">
        <button
          type="button"
          onClick={() => toggleGroup(group.id)}
          className="w-full px-4 py-3 bg-panel-card flex items-center justify-between hover:bg-panel-dark transition-colors"
        >
          <div className="flex items-center gap-3">
            {group.icon && <span className="text-xl">{group.icon}</span>}
            <div className="text-left">
              <h3 className="font-medium text-white">{group.name}</h3>
              {group.description && (
                <p className="text-xs text-gray-400">{group.description}</p>
              )}
            </div>
          </div>
          <svg
            className={`w-5 h-5 text-gray-400 transition-transform ${isExpanded ? 'rotate-180' : ''}`}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </button>
        
        {isExpanded && (
          <div className="p-4 space-y-4 bg-panel-card/50">
            {groupVars.map(renderVariable)}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="space-y-6">
      {/* Render grouped variables */}
      {groups.map(renderGroup)}
      
      {/* Render ungrouped variables */}
      {groupedVariables.ungrouped && groupedVariables.ungrouped.length > 0 && (
        <div className="space-y-4">
          {groups.length > 0 && (
            <h3 className="font-medium text-white">Other Settings</h3>
          )}
          {groupedVariables.ungrouped.map(renderVariable)}
        </div>
      )}
    </div>
  );
};

// Helper component for displaying resource limits
interface ResourceLimitDisplayProps {
  memory?: { min: number; max: number; default: number };
  cpu?: { min: number; max: number; default: number };
  disk?: { min: number; default: number };
  values: {
    memory: number;
    cpu: number;
    disk: number;
  };
  onChange: (values: { memory: number; cpu: number; disk: number }) => void;
}

export const ResourceLimitSelector: React.FC<ResourceLimitDisplayProps> = ({
  memory,
  cpu,
  disk,
  values,
  onChange,
}) => {
  return (
    <div className="space-y-6">
      {memory && (
        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-300">
            Memory (RAM)
          </label>
          <div className="flex items-center gap-4">
            <input
              type="range"
              min={memory.min}
              max={memory.max}
              step={256}
              value={values.memory}
              onChange={(e) => onChange({ ...values, memory: parseInt(e.target.value) })}
              className="flex-1 h-2 bg-panel-border rounded-lg appearance-none cursor-pointer accent-purple-500"
            />
            <div className="flex items-center gap-1 min-w-[100px]">
              <input
                type="number"
                min={memory.min}
                max={memory.max}
                step={256}
                value={values.memory}
                onChange={(e) => onChange({ ...values, memory: parseInt(e.target.value) })}
                className="w-20 px-2 py-1 bg-panel-dark border border-panel-border rounded text-white text-sm text-center"
              />
              <span className="text-gray-400 text-sm">MB</span>
            </div>
          </div>
          <p className="text-xs text-gray-500">
            Min: {memory.min}MB | Max: {memory.max}MB
          </p>
        </div>
      )}

      {cpu && (
        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-300">
            CPU Limit
          </label>
          <div className="flex items-center gap-4">
            <input
              type="range"
              min={cpu.min}
              max={cpu.max}
              step={5}
              value={values.cpu}
              onChange={(e) => onChange({ ...values, cpu: parseInt(e.target.value) })}
              className="flex-1 h-2 bg-panel-border rounded-lg appearance-none cursor-pointer accent-purple-500"
            />
            <div className="flex items-center gap-1 min-w-[80px]">
              <input
                type="number"
                min={cpu.min}
                max={cpu.max}
                step={5}
                value={values.cpu}
                onChange={(e) => onChange({ ...values, cpu: parseInt(e.target.value) })}
                className="w-16 px-2 py-1 bg-panel-dark border border-panel-border rounded text-white text-sm text-center"
              />
              <span className="text-gray-400 text-sm">%</span>
            </div>
          </div>
          <p className="text-xs text-gray-500">
            Min: {cpu.min}% | Max: {cpu.max}%
          </p>
        </div>
      )}

      {disk && (
        <div className="space-y-2">
          <label className="block text-sm font-medium text-gray-300">
            Disk Space
          </label>
          <div className="flex items-center gap-4">
            <input
              type="range"
              min={disk.min}
              max={disk.min * 10}
              step={1024}
              value={values.disk}
              onChange={(e) => onChange({ ...values, disk: parseInt(e.target.value) })}
              className="flex-1 h-2 bg-panel-border rounded-lg appearance-none cursor-pointer accent-purple-500"
            />
            <div className="flex items-center gap-1 min-w-[100px]">
              <input
                type="number"
                min={disk.min}
                value={values.disk}
                onChange={(e) => onChange({ ...values, disk: parseInt(e.target.value) })}
                className="w-20 px-2 py-1 bg-panel-dark border border-panel-border rounded text-white text-sm text-center"
              />
              <span className="text-gray-400 text-sm">MB</span>
            </div>
          </div>
          <p className="text-xs text-gray-500">
            Minimum: {disk.min}MB ({(disk.min / 1024).toFixed(1)}GB)
          </p>
        </div>
      )}
    </div>
  );
};

export default DynamicVariableForm;

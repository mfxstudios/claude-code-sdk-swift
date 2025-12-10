#!/usr/bin/env node
/**
 * sdk-wrapper.mjs
 * Node.js wrapper for @anthropic-ai/claude-agent-sdk SDK
 *
 * This script bridges Swift and the Claude Code SDK by:
 * 1. Receiving configuration via command-line arguments (JSON)
 * 2. Executing queries through the SDK
 * 3. Streaming results as JSONL to stdout
 */

import { query } from '@anthropic-ai/claude-agent-sdk';

/**
 * Maps Swift-style configuration to SDK options
 */
function mapOptions(options) {
    const sdkOptions = {};

    if (options.model) {
        sdkOptions.model = options.model;
    }

    if (options.max_turns !== undefined) {
        sdkOptions.maxTurns = options.max_turns;
    }

    if (options.max_thinking_tokens !== undefined) {
        sdkOptions.maxThinkingTokens = options.max_thinking_tokens;
    }

    // Handle system prompt - Agent SDK expects an object format for appending
    // See: https://platform.claude.com/docs/en/agent-sdk/modifying-system-prompts
    if (options.append_system_prompt) {
        // Use claude_code preset with append to preserve tool instructions
        sdkOptions.systemPrompt = {
            type: 'preset',
            preset: 'claude_code',
            append: options.append_system_prompt
        };
    } else if (options.system_prompt) {
        // Custom system prompt replaces the default entirely
        sdkOptions.systemPrompt = options.system_prompt;
    }

    if (options.allowed_tools) {
        sdkOptions.allowedTools = options.allowed_tools;
    }

    if (options.disallowed_tools) {
        sdkOptions.disallowedTools = options.disallowed_tools;
    }

    if (options.permission_mode) {
        sdkOptions.permissionMode = options.permission_mode;
    }

    if (options.continue) {
        sdkOptions.continue = true;
    }

    if (options.resume) {
        sdkOptions.resume = options.resume;
    }

    if (options.mcp_servers) {
        sdkOptions.mcpServers = options.mcp_servers;
    }

    return sdkOptions;
}

/**
 * Outputs a message as JSON line to stdout
 */
function outputMessage(message) {
    console.log(JSON.stringify(message));
}

/**
 * Main entry point
 */
async function main() {
    // Parse configuration from command line argument
    const configJson = process.argv[2];

    if (!configJson) {
        console.error('Usage: node sdk-wrapper.mjs \'<json-config>\'');
        process.exit(1);
    }

    let config;
    try {
        config = JSON.parse(configJson);
    } catch (error) {
        console.error('Failed to parse configuration JSON:', error.message);
        process.exit(1);
    }

    const { prompt, options = {} } = config;

    if (!prompt) {
        console.error('No prompt provided in configuration');
        process.exit(1);
    }

    // Map options to SDK format
    const sdkOptions = mapOptions(options);

    // Debug output to stderr (only when DEBUG or CLAUDE_DEBUG is set)
    if (process.env.DEBUG || process.env.CLAUDE_DEBUG) {
        console.error('[sdk-wrapper] Prompt length:', prompt.length);
        console.error('[sdk-wrapper] Options:', JSON.stringify(sdkOptions, null, 2));
        if (sdkOptions.resume) {
            console.error('[sdk-wrapper] Resuming session:', sdkOptions.resume);
        }
    }

    let toolsUsed = false;

    try {
        // Execute the query and stream results
        // Note: Agent SDK expects options in an 'options' object
        for await (const message of query({ prompt, options: sdkOptions })) {
            // Track if tools were used
            if (message.type === 'assistant' && message.message?.content) {
                for (const content of message.message.content) {
                    if (content.type === 'tool_use') {
                        toolsUsed = true;
                    }
                }
            }

            // Output each message as a JSON line
            outputMessage(message);
        }
    } catch (error) {
        // Output error as a result message
        outputMessage({
            type: 'result',
            subtype: 'error',
            is_error: true,
            result: error.message,
            session_id: '',
            total_cost_usd: 0,
            duration_ms: 0,
            duration_api_ms: 0,
            num_turns: 0,
        });
        process.exit(1);
    }

    // Smart exit: immediate if no tools used, delayed if tools were used
    // This allows MCP servers time to shut down properly
    if (toolsUsed) {
        setTimeout(() => process.exit(0), 100);
    } else {
        process.exit(0);
    }
}

main();

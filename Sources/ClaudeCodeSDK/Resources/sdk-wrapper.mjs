#!/usr/bin/env node
/**
 * sdk-wrapper.mjs
 * Node.js wrapper for @anthropic-ai/claude-agent-sdk SDK
 *
 * This script bridges Swift and the Claude Code SDK by:
 * 1. Receiving configuration via command-line arguments (JSON)
 * 2. Executing queries through the SDK
 * 3. Streaming results as JSONL to stdout
 * 4. Supporting bidirectional IPC for user questions and tool permissions
 */

import { query } from '@anthropic-ai/claude-agent-sdk';
import { createInterface } from 'readline';

// MARK: - Bidirectional IPC for interactive mode

/** Map of pending request IDs to their resolve functions */
const pendingRequests = new Map();

/** Counter for generating unique request IDs */
let requestIdCounter = 0;

/** Readline interface for receiving responses from Swift via stdin */
let stdinReader = null;

/**
 * Initializes the stdin reader for receiving responses from Swift.
 * Only called when interactive mode is enabled.
 */
function initStdinReader() {
    if (stdinReader) return;

    stdinReader = createInterface({
        input: process.stdin,
        terminal: false,
    });

    stdinReader.on('line', (line) => {
        try {
            const response = JSON.parse(line);
            const requestId = response.request_id;

            if (requestId && pendingRequests.has(requestId)) {
                const resolve = pendingRequests.get(requestId);
                pendingRequests.delete(requestId);
                resolve(response);
            } else if (process.env.DEBUG || process.env.CLAUDE_DEBUG) {
                console.error('[sdk-wrapper] Unknown or expired request_id:', requestId);
            }
        } catch (error) {
            if (process.env.DEBUG || process.env.CLAUDE_DEBUG) {
                console.error('[sdk-wrapper] Failed to parse stdin response:', error.message);
            }
        }
    });
}

/**
 * Sends an input request to Swift via stdout and waits for the response via stdin.
 *
 * @param {string} inputType - Either 'user_question' or 'tool_permission'
 * @param {object} payload - The request payload
 * @returns {Promise<object>} The response from Swift
 */
function sendInputRequest(inputType, payload) {
    return new Promise((resolve) => {
        const requestId = `req_${++requestIdCounter}`;
        pendingRequests.set(requestId, resolve);

        outputMessage({
            type: 'input_request',
            request_id: requestId,
            input_type: inputType,
            payload,
        });
    });
}

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

    if (options.permission_prompt_tool) {
        sdkOptions.permissionPromptTool = options.permission_prompt_tool;
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

    // Extended thinking configuration
    if (options.thinking) {
        sdkOptions.thinking = options.thinking;
    }

    // Speed mode
    if (options.speed) {
        sdkOptions.speed = options.speed;
    }

    // Beta features
    if (options.beta_features && options.beta_features.length > 0) {
        sdkOptions.betas = options.beta_features;
    }

    // Structured output configuration
    if (options.output_config) {
        sdkOptions.outputConfig = options.output_config;
    }

    // Interactive mode: set up canUseTool callback for user questions and permissions
    if (options.interactive) {
        initStdinReader();

        sdkOptions.canUseTool = async (toolName, input) => {
            if (toolName === 'AskUserQuestion') {
                // Claude is asking the user clarifying questions
                const response = await sendInputRequest('user_question', {
                    questions: input.questions || [],
                });
                // Return the answers to be injected as the tool result
                return { result: response.answers || {} };
            }

            // For all other tools, request permission from Swift
            const response = await sendInputRequest('tool_permission', {
                tool_name: toolName,
                input: input || {},
            });

            if (response.decision === 'allow') {
                return undefined; // undefined = allow tool use
            }
            return {
                denied: true,
                reason: response.reason || 'Denied by user',
            };
        };
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
        if (options.interactive) {
            console.error('[sdk-wrapper] Interactive mode enabled');
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

    // Clean up stdin reader if it was initialized
    if (stdinReader) {
        stdinReader.close();
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

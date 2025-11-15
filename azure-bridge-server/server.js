// server.js
// npm i express ws microsoft-cognitiveservices-speech-sdk
const express = require('express');
const WebSocket = require('ws');
const sdk = require('microsoft-cognitiveservices-speech-sdk');

const PORT = process.env.PORT || 3000;

const app = express();
const server = app.listen(PORT, () => console.log(`Azure Speech Bridge Server listening on port ${PORT}`));
const wss = new WebSocket.Server({ server });

wss.on('connection', (ws, req) => {
  console.log('Client connected');

  let recognizer = null;
  let pushStream = null;
  let azureKey = null;
  let azureRegion = null;
  let language = 'en-US';

  ws.on('message', (msg) => {    
    // Handle Buffer that might be text
    if (msg instanceof Buffer) {
      try {
        const text = msg.toString('utf8');
        // Try to parse as JSON to see if it's a control message
        if (text[0] != '{') {
            throw new Error('Not JSON');
        }
        const data = JSON.parse(text);
        console.log('Received command (from Buffer):', text);
        
        if (data.cmd === 'config') {
          // Initialize Azure Speech recognizer with provided credentials
          azureKey = data.key;
          azureRegion = data.region;
          language = data.language || 'en-US';

          if (!azureKey || !azureRegion) {
            ws.send(JSON.stringify({ 
              type: 'error', 
              message: 'Azure key and region are required' 
            }));
            return;
          }

          console.log(`Initializing Azure Speech: region=${azureRegion}, language=${language}`);

          // Set up Azure speech recognizer using push stream
          const speechConfig = sdk.SpeechConfig.fromSubscription(azureKey, azureRegion);
          speechConfig.speechRecognitionLanguage = language;
          
          // Enable aggressive partial results - very low latency
          speechConfig.setProperty(sdk.PropertyId.SpeechServiceResponse_RequestWordLevelTimestamps, "true");
          speechConfig.setProperty(sdk.PropertyId.SpeechServiceResponse_RequestSentenceBoundary, "true");
          speechConfig.setProperty(sdk.PropertyId.Speech_SegmentationSilenceTimeoutMs, "100"); // Very aggressive - 100ms
          speechConfig.setProperty(sdk.PropertyId.SpeechServiceConnection_InitialSilenceTimeoutMs, "3000");
          speechConfig.setProperty(sdk.PropertyId.SpeechServiceConnection_EndSilenceTimeoutMs, "100");
          
          // Enable immediate interim results with maximum responsiveness
          speechConfig.setProperty("SPEECH-WordLevelTimingEnabled", "true");
          speechConfig.setProperty("SPEECH-SegmentationStrategy", "Custom");
          speechConfig.setProperty("SPEECH-SegmentationMaximumSilence", "100");
          speechConfig.setProperty("SPEECH-TranslationStablePartialThreshold", "1");
          
          // Request partial results as aggressively as possible
          speechConfig.outputFormat = sdk.OutputFormat.Simple;
          
          // Disable profanity filter
          speechConfig.setProfanity(sdk.ProfanityOption.Raw);

          pushStream = sdk.AudioInputStream.createPushStream(
            sdk.AudioStreamFormat.getWaveFormatPCM(16000, 16, 1)
          );
          const audioConfig = sdk.AudioConfig.fromStreamInput(pushStream);
          recognizer = new sdk.SpeechRecognizer(speechConfig, audioConfig);

          // Send recognition events to client
          recognizer.recognizing = (s, e) => {
            // Partial result
            if (e.result && e.result.text) {
              ws.send(JSON.stringify({ type: 'partial', text: e.result.text }));
            }
          };

          recognizer.recognized = (s, e) => {
            // Final result (may be empty on no-match)
            if (e.result && e.result.text) {
              ws.send(JSON.stringify({ type: 'final', text: e.result.text }));
            }
          };

          recognizer.canceled = (s, e) => {
            console.log('Recognition canceled:', e.reason, e.errorDetails);
            ws.send(JSON.stringify({ 
              type: 'canceled', 
              reason: e.reason, 
              details: e.errorDetails 
            }));
          };

          recognizer.sessionStopped = () => {
            console.log('Session stopped');
            ws.send(JSON.stringify({ type: 'sessionStopped' }));
          };

          recognizer.startContinuousRecognitionAsync(
            () => {
              console.log('Recognition started');
              ws.send(JSON.stringify({ type: 'started' }));
            },
            (err) => {
              console.error('Error starting recognition:', err);
              ws.send(JSON.stringify({ type: 'error', message: err.toString() }));
            }
          );
          return;
        } else if (data.cmd === 'stop') {
          console.log('Stop command received');
          if (pushStream) {
            pushStream.close();
          }
          if (recognizer) {
            recognizer.stopContinuousRecognitionAsync(() => {
              console.log('Recognition stopped');
              ws.close();
            });
          }
          return;
        }
      } catch (e) {
        // Not JSON, treat as audio data
        if (pushStream) {
          // Convert Node.js Buffer to ArrayBuffer for Azure SDK
          const arrayBuffer = msg.buffer.slice(msg.byteOffset, msg.byteOffset + msg.byteLength);
          pushStream.write(arrayBuffer);
        }
      }
      return;
    }
    
    // Handle text messages (config/control)
    if (typeof msg === 'string') {
      try {
        const data = JSON.parse(msg);
        console.log('Received command:', msg);
        
        if (data.cmd === 'config') {
          // Initialize Azure Speech recognizer with provided credentials
          azureKey = data.key;
          azureRegion = data.region;
          language = data.language || 'en-US';

          if (!azureKey || !azureRegion) {
            ws.send(JSON.stringify({ 
              type: 'error', 
              message: 'Azure key and region are required' 
            }));
            return;
          }

          console.log(`Initializing Azure Speech: region=${azureRegion}, language=${language}`);

          // Set up Azure speech recognizer using push stream
          const speechConfig = sdk.SpeechConfig.fromSubscription(azureKey, azureRegion);
          speechConfig.speechRecognitionLanguage = language;
          
          // Enable aggressive partial results - very low latency
          speechConfig.setProperty(sdk.PropertyId.SpeechServiceResponse_RequestWordLevelTimestamps, "true");
          speechConfig.setProperty(sdk.PropertyId.SpeechServiceResponse_RequestSentenceBoundary, "true");
          speechConfig.setProperty(sdk.PropertyId.Speech_SegmentationSilenceTimeoutMs, "100"); // Very aggressive - 100ms
          speechConfig.setProperty(sdk.PropertyId.SpeechServiceConnection_InitialSilenceTimeoutMs, "3000");
          speechConfig.setProperty(sdk.PropertyId.SpeechServiceConnection_EndSilenceTimeoutMs, "100");
          
          // Enable immediate interim results with maximum responsiveness
          speechConfig.setProperty("SPEECH-WordLevelTimingEnabled", "true");
          speechConfig.setProperty("SPEECH-SegmentationStrategy", "Custom");
          speechConfig.setProperty("SPEECH-SegmentationMaximumSilence", "100");
          speechConfig.setProperty("SPEECH-TranslationStablePartialThreshold", "1");
          
          // Request partial results as aggressively as possible
          speechConfig.outputFormat = sdk.OutputFormat.Simple;
          
          // Disable profanity filter
          speechConfig.setProfanity(sdk.ProfanityOption.Raw);
          speechConfig.enableAudioLogging(); // Optional: enable audio logging for debugging
          speechConfig.enableDictation(); // Optional: enable dictation mode

          pushStream = sdk.AudioInputStream.createPushStream(
            sdk.AudioStreamFormat.getWaveFormatPCM(16000, 16, 1)
          );
          const audioConfig = sdk.AudioConfig.fromStreamInput(pushStream);
          recognizer = new sdk.ConversationTranscriber(speechConfig, audioConfig);

          // Send recognition events to client
          recognizer.recognizing = (s, e) => {
            // Partial result
            if (e.result && e.result.text) {
              ws.send(JSON.stringify({ type: 'partial', text: e.result.text }));
            }
          };

          recognizer.recognized = (s, e) => {
            // Final result (may be empty on no-match)
            if (e.result && e.result.text) {
              ws.send(JSON.stringify({ type: 'final', text: e.result.text }));
            }
          };

          recognizer.canceled = (s, e) => {
            console.log('Recognition canceled:', e.reason, e.errorDetails);
            ws.send(JSON.stringify({ 
              type: 'canceled', 
              reason: e.reason, 
              details: e.errorDetails 
            }));
          };

          recognizer.sessionStopped = () => {
            console.log('Session stopped');
            ws.send(JSON.stringify({ type: 'sessionStopped' }));
          };

          recognizer.startContinuousRecognitionAsync(
            () => {
              console.log('Recognition started');
              ws.send(JSON.stringify({ type: 'started' }));
            },
            (err) => {
              console.error('Error starting recognition:', err);
              ws.send(JSON.stringify({ type: 'error', message: err.toString() }));
            }
          );
        } else if (data.cmd === 'stop') {
          console.log('Stop command received');
          if (pushStream) {
            pushStream.close();
          }
          if (recognizer) {
            recognizer.stopContinuousRecognitionAsync(() => {
              console.log('Recognition stopped');
              ws.close();
            });
          }
        }
      } catch (e) {
        console.error('Error parsing message:', e);
      }
      return;
    }

    // This shouldn't be reached since all messages come as Buffer
    console.warn('Unexpected message type:', typeof msg);
  });

  ws.on('close', () => {
    console.log('Client disconnected');
    try { 
      if (pushStream) pushStream.close(); 
    } catch(e) {
      console.error('Error closing push stream:', e);
    }
    try { 
      if (recognizer) recognizer.close(); 
    } catch(e) {
      console.error('Error closing recognizer:', e);
    }
  });

  ws.on('error', (err) => {
    console.error('WebSocket error:', err);
  });
});

console.log('Azure Speech Bridge Server ready');
console.log('Clients should send config with Azure credentials before streaming audio');

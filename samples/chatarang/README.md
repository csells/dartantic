# Chatarang

A command-line chat application that uses Large Language Models (LLMs) and can be extended with tools to interact with the world.

## Features

*   **Multi-Provider Support**: Chat with models from Google, OpenAI, and OpenRouter.
*   **Dynamic Model Switching**: Change the active LLM at any time with the `/model` command.
*   **Conversation History**: View the full history of your conversation, including tool usage, with the `/messages` command.
*   **Extensible Tool Use**: The agent can use a set of predefined tools to answer questions and perform actions.
*   **Rich Command Set**: A suite of slash commands for controlling the application (`/help`, `/models`, `/model`, `/messages`, `/exit`).

### Included Tools

*   `current-time`: Gets the current time.
*   `current-date`: Gets the current date.
*   `weather`: Gets the weather for a given US zipcode.
*   `location-lookup`: Looks up geographic data for any location query using OpenStreetMap.
*   `surf-web`: Fetches the content of a web page.

## Setup

1.  **Create an Environment File**:
    This project requires API keys to function. Create a `.env` file in the root of the project with your keys:
    ```sh
    GEMINI_API_KEY=your_google_api_key
    OPENAI_API_KEY=your_openai_api_key
    OPENROUTER_API_KEY=your_openrouter_api_key
    ```

2.  **Install Dependencies**:
    ```sh
    dart pub get
    ```

3.  **Run the Application**:
    ```sh
    dart run
    ```

## Sample Usage

### Basic Conversation

You can have a normal conversation, and the agent will remember the context across different models.

```
You: my name is chris
google:gemini-2.0-flash: Okay, Chris. How can I help you today?

You: /model openai:gpt-4o
Model set to: openai:gpt-4o

You: say my name
openai:gpt-4o: Your name is Chris. How can I assist you further?
```

### Multi-Step Tool Use

The agent can reason about how to combine tools to answer complex questions.

```
You: what's the weather at the moda center in portland, or?
Tool.call: location-lookup({
  "location": "Moda Center, Portland, OR"
})
Tool.result: location-lookup: {
  "result": [
    {
      "place_id": 301178490,
      "licence": "Data © OpenStreetMap contributors, ODbL 1.0. http://osm.org/copyright",
      "osm_type": "way",
      "osm_id": 24635906,
      "lat": "45.5315787",
      "lon": "-122.6668337",
      "address": {
        "postcode": "97240",
        ...
      },
      ...
    }
  ]
}
Tool.call: weather({
  "zipcode": "97240"
})
Tool.result: weather: {
  "result": {
    "current_condition": [
      {
        "FeelsLikeF": "53",
        "humidity": "89",
        ...
      }
    ]
  }
}
google:gemini-2.0-flash: The weather at the Moda Center in Portland, OR is currently 55°F with light rain and mist. The wind is from the south at 9 mph. The UV index is 1.
```

### Viewing Conversation History

The `/messages` command displays the entire conversation, including all tool interactions.

```
You: /messages

You: my name is chris
google:gemini-2.0-flash: Okay, Chris. How can I help you today?

You: what's the weather at the moda center in portland, or?
google:gemini-2.0-flash: 
Tool.call: location-lookup({"location":"Moda Center, Portland, OR"})
Tool.result: location-lookup: { ... }
Tool.call: weather({"zipcode":"97240"})
Tool.result: weather: { ... }
The weather at the Moda Center in Portland, OR is currently 55°F with light rain and mist. The wind is from the south at 9 mph. The UV index is 1.
```

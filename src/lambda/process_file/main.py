import boto3
import os
import json
from openai import OpenAI

def get_react_components(html_content):
    client = OpenAI(api_key=os.environ['OPENAI_API_KEY'])
    
    prompt = f"""You are a React developer agent. Please convert this HTML file into a modern React component with core CSS styling.
    Everything in the HTML code will be given as a div. You should turn the necessary places into buttons, input boxes and other necessary components.

    Create two files:
    1. App.js - A React functional component with mock data. Please use 
    2. style.css - CSS styles needed
    
    Here's the HTML content:
    {html_content}
    
    Respond with a JSON object containing both files as strings. Make sure the React component uses 'style.css' built-in classes.
    Example response format:
    {{
        "App.js": "import React from 'react';\n\nexport default function App() {{ ... }}",
        "style.css": ".custom-class {{ ... }}"
    }}
    """
    
    try:
        response = client.chat.completions.create(
            model="gpt-4-turbo-preview",
            messages=[{
                "role": "user",
                "content": prompt
            }],
            max_tokens=4000,
            temperature=0.7
        )
        
        
        response_content = response.choices[0].message.content
        
        
        if '```json' in response_content:
            json_str = response_content.split('```json')[1].split('```')[0].strip()
        else:
            
            start_idx = response_content.find('{')
            end_idx = response_content.rfind('}') + 1
            if start_idx != -1 and end_idx != 0:
                json_str = response_content[start_idx:end_idx]
            else:
                raise ValueError("Could not find valid JSON in response")
        
        
        components = json.loads(json_str)
        
        
        if 'App.js' not in components or 'style.css' not in components:
            raise ValueError("Response missing required files")
            
        return components
        
    except Exception as e:
        print(f"Error in get_react_components: {str(e)}")
        print(f"Raw response: {response_content}")
        raise

def handler(event, context):
    try:
        s3_client = boto3.client('s3')
        
        
        source_bucket = event['Records'][0]['s3']['bucket']['name']
        source_key = event['Records'][0]['s3']['object']['key']
        
        print(f"Processing file {source_key} from bucket {source_bucket}")
        
        
        response = s3_client.get_object(Bucket=source_bucket, Key=source_key)
        html_content = response['Body'].read().decode('utf-8')
        
        
        components = get_react_components(html_content)
        
        destination_bucket = os.environ['DESTINATION_BUCKET']
        
        
        s3_client.put_object(
            Bucket=destination_bucket,
            Key='App.js',
            Body=components['App.js'],
            ContentType='application/javascript'
        )
        
        
        s3_client.put_object(
            Bucket=destination_bucket,
            Key='style.css',
            Body=components['style.css'],
            ContentType='text/css'
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Successfully converted HTML to React components',
                'files': ['App.js', 'style.css']
            })
        }
        
    except Exception as e:
        print(f"Error in handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
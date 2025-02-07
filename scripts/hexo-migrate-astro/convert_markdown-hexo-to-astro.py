import os
import re
from datetime import datetime

def convert_markdown(input_file, output_dir):
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Read the input file
    with open(input_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Split content into front matter and body
    parts = content.split('---', 2)
    if len(parts) < 3:
        return
    
    # Process front matter
    front_matter = parts[1].strip()
    body = parts[2].strip()
    
    # Convert front matter
    new_front_matter = []
    remove_keys = ['mathjax', 'categories']
    
    lines = front_matter.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if ':' in line:
            key, value = [x.strip() for x in line.split(':', 1)]
            if key in remove_keys:
                i += 1
                continue
            if key == 'date':
                new_front_matter.append(f'pubDatetime: {value}')
            elif key in ['update', 'updated']:
                new_front_matter.append(f'modDatetime: {value}')
            else:
                new_front_matter.append(line)
                # Check for multi-line values (like tags)
                while i + 1 < len(lines) and lines[i + 1].startswith(' '):
                    new_front_matter.append(lines[i + 1])
                    i += 1
        i += 1
    
    # Extract description (content between front matter and <!-- more -->)
    description_match = re.search(r'---\s*\n.*?\n---\s*\n(.*?)\n\s*<!-- more -->', content, re.DOTALL)
    if description_match:
        # Get only the first line of description
        description = description_match.group(1).strip().split('\n')[0].strip()
        new_front_matter.append(f'description: {description}')
        # Remove <!-- more --> and normalize spacing
        body = re.sub(r'\n\s*<!-- more -->\s*\n', '\n\n', body, flags=re.MULTILINE)

    # Create new content
    new_content = '---\n' + '\n'.join(new_front_matter) + '\n---\n' + body
    
    # Write to output file
    output_file = os.path.join(output_dir, os.path.basename(input_file))
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(new_content)

def process_directory(input_dir, output_dir):
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Walk through all files in input directory
    for root, _, files in os.walk(input_dir):
        for file in files:
            if file.endswith('.md'):
                # Get relative path to maintain directory structure
                rel_path = os.path.relpath(root, input_dir)
                # Create corresponding output directory
                out_dir = os.path.join(output_dir, rel_path)
                os.makedirs(out_dir, exist_ok=True)
                
                # Convert the markdown file
                input_file = os.path.join(root, file)
                convert_markdown(input_file, out_dir)

if __name__ == '__main__':
    input_dir = './input'
    output_dir = './output'
    process_directory(input_dir, output_dir)

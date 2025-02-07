import os

def generate_routes(input_dir, output_file):
    routes = []
    for root, _, files in os.walk(input_dir):
        for file in files:
            if file.endswith('.md'):
                # Remove .md extension
                base_name = file[:-3]
                # Create the route entries
                route = f'"/{base_name}": "/posts/{base_name}"'
                routes.append(route)
    
    # Sort routes for consistent output
    routes.sort()
    
    # Write to output file
    with open(output_file, 'w') as f:
        for i, route in enumerate(routes):
            if i < len(routes) - 1:
                f.write(f"{route},\n")
            else:
                f.write(f"{route}\n")

if __name__ == '__main__':
    input_dir = './input'
    output_file = './routes.txt'
    generate_routes(input_dir, output_file)

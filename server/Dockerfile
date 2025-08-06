# Use official Node.js LTS base image
FROM node:18

# Set the working directory in the container
WORKDIR /server

# Copy package.json and package-lock.json to install dependencies
COPY package*.json ./

# Install production dependencies
RUN npm ci --only=production

# Copy the rest of your app
COPY . .

# Expose the port your app runs on (Cloud Run expects 8080)
EXPOSE 8080

# Start the server (replace with your actual entry file)
CMD ["node", "index.js"]

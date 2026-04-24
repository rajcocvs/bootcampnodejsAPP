FROM node:18

WORKDIR /app

# copy ONLY built files, not source
COPY dist/ .

CMD ["node", "app.js"]

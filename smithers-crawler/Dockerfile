FROM node:18

# Copy repo
COPY --from=repo . /smithers-crawler
WORKDIR /smithers-crawler

# Copy credentials
# COPY ./credentials/gcloud.json ./credentials/gcloud.json

RUN npm install
RUN npm run build

# gcp
# ENV GOOGLE_APPLICATION_CREDENTIALS ./credentials/gcloud.json
# ENV DB_SECRET_NAME production-psql
ENV NODE_ENV production

ENTRYPOINT ["npm", "run", "start"]
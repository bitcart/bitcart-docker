BITCARTGEN_DOCKER_IMAGE='mrnaif/docker-compose-generator'

docker run -v "$PWD/compose:/app/compose" \
    -e BITCART_ONE_HOST=$BITCART_ONE_HOST \
    --rm $BITCARTGEN_DOCKER_IMAGE
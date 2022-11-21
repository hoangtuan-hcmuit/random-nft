const ramdomNumber = Math.floor(Math.random() * 1000);

console.log(randomNumber)

function random(randomNumber) {
  if (randomNumber < 500) {
  console.log("GENERIC");
}
else if (randomNumber > 499 && randomNumber < 700) {
  console.log("COMMON");
}
else if (randomNumber > 699 && randomNumber < 900) {
  console.log("RARE");
}
else if (randomNumber > 899 && randomNumber < 950) {
  console.log("EPIC");
}
else if (randomNumber > 949 && randomNumber < 1000) {
  console.log("ICONIC");
}
}

random(randomNumber);
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "private_subnet_id" {
  value = aws_subnet.private.id
}

output "public_subnet_b_id" {
  value = aws_subnet.public_b.id
}
output "private_subnet_b_id" {
  value = aws_subnet.private_b.id
}

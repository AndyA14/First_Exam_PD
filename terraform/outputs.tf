output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.alb.dns_name
}

output "load_balancer_name" {
  description = "ALB name"
  value       = aws_lb.alb.name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.alb.arn
}

output "target_group_arn" {
  description = "Target Group ARN"
  value       = aws_lb_target_group.tg.arn
}

output "listener_arn" {
  description = "Listener ARN"
  value       = aws_lb_listener.http.arn
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.asg.name
}

output "launch_template_id" {
  description = "Launch Template ID"
  value       = aws_launch_template.lt.id
}

output "ami_used" {
  description = "AMI ID used by Launch Template"
  value       = data.aws_ami.amazon_linux.id
}

output "vpc_id" {
  description = "VPC ID created by Terraform"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

output "alb_security_group_id" {
  description = "Security Group ID attached to ALB"
  value       = aws_security_group.alb_sg.id
}

output "ec2_security_group_id" {
  description = "Security Group ID attached to EC2 instances"
  value       = aws_security_group.ec2_sg.id
}

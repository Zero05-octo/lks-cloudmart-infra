# ============================================================
# OUTPUTS — CloudMart Infrastructure
# Uncomment dan sesuaikan nama resource setelah dibuat
# ============================================================

output "vpc_id" {
  value = aws_vpc.lks_mart_vpc.id
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "rds_endpoint" {
  value = aws_db_instance.MySQL.endpoint
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.Redis.cache_nodes[0].address
}

output "sqs_url" {
  value = aws_sqs_queue.SQS.url
}

output "sns_topic_arn" {
  value = aws_sns_topic.notification.arn
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.cluster.name
}

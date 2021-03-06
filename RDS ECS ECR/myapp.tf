data "template_file" "myapp-task-definition-template" {
  template = "${file("app.json.tpl")}"
  vars = {
    REPOSITORY_URL = "${replace("${aws_ecr_repository.myapp.repository_url}", "https://", "")}"
    db_host="${aws_db_instance.mysql.address}"
    db_user="${var.DB_USER}"
    db_password="${var.DB_PASSWORD}"
  }
}

resource "aws_ecs_task_definition" "myaap-task-definition" {
  family                = "myapp"
  container_definitions = "${data.template_file.myapp-task-definition-template.rendered}"
}

resource "aws_elb" "myaap_elb" {
  name = "myaap-elb"

  listener {
    instance_port     = 3000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 30
    target              = "HTTP:3000/"
    interval            = 60
  }
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  subnets         = ["${aws_subnet.main-public-1.id}", "${aws_subnet.main-public-2.id}"]
  security_groups = ["${aws_security_group.myapp-elb-securitygroup.id}"]

  tags = {
    Name = "myapp-elb"
  }
}

resource "aws_ecs_service" "myapp-service" {
  name            = "myapp"
  cluster         = "${aws_ecs_cluster.example-cluster.id}"
  task_definition = "${aws_ecs_task_definition.myaap-task-definition.arn}"
  desired_count   = 1
  iam_role        = "${aws_iam_role.ecs-service-role.arn}"
  depends_on      = ["aws_iam_policy_attachment.ecs-service-attache1"]

  load_balancer {
    elb_name       = "${aws_elb.myaap_elb.name}"
    container_name = "myapp"
    container_port = 8080
  }
  lifecycle { ignore_changes = ["task_definition"] }

}
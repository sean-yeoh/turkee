# Go to this page https://aws-portal.amazon.com/gp/aws/developer/account/index.html?action=access-key
# to retrieve your AWS/Mechanical Turk access keys.

AWSACCESSKEYID      = 'XXXXXXXXXXXXXXXXXX'
AWSSECRETACCESSKEY  = 'YYYYYYYYYYYYYYYYYYYYYYYYYYYY'

Turkee::TurkAPI.setup(AWSACCESSKEYID, AWSSECRETACCESSKEY, :sandbox => (Rails.env == 'production' ? false : true))

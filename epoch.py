import argparse
import calendar
import time

current_time = calendar.timegm(time.gmtime())

parser = argparse.ArgumentParser(description='--t "<epoch time value>"')
parser.add_argument("--t", default=current_time, help="'current epoch time is `date +%s`'")
args = parser.parse_args()

t = args.t
t = str(t)[:10]  # 10 digit long epoch is valid till 'January 18, 2038'; then it will be 11 digits long


def convert_epoch():
    # print current epoch if no argument & exit
    if t == str(current_time)[:10]:
        print("Current EPOCH time is: "+(str(t)))
        exit()

    readable_date = time.strftime('%m/%d/%Y %H:%M:%S', time.localtime(int(t)))
    print("Human-readable date:\n"+readable_date)


convert_epoch()

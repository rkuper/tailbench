#!/usr/bin/python3

import sys
import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from scipy import stats
from scipy import mean

class Lat(object):
    def __init__(self, fileName):
        f = open(fileName, 'rb')
        a = np.fromfile(f, dtype=np.uint64)
        self.reqTimes = a.reshape((int(a.shape[0]/3), 3))
        f.close()

    def parseQueueTimes(self):
        return self.reqTimes[:, 0]

    def parseSvcTimes(self):
        return self.reqTimes[:, 1]

    def parseSojournTimes(self):
        return self.reqTimes[:, 2]

def draw_pdf(values, nbins):
    clear()
    return pd.Series(values).hist(bins=nbins)

def savefig(pathname):
    plt.savefig(pathname)

def clear():
    plt.cla()
    plt.clf()
    plt.close()

if __name__ == '__main__':
    """
    data = np.loadtxt('Filename.txt')
    # Choose how many bins you want here
    num_bins = 20
    # Use the histogram function to bin the data
    counts, bin_edges = np.histogram(data, bins=num_bins, normed=True)
    # Now find the cdf
    cdf = np.cumsum(counts)
    # And finally plot the cdf
    plt.plot(bin_edges[1:], cdf)
    plt.show()
    """

    def getLatPct(latsFile):
        assert os.path.exists(latsFile)

        latsObj = Lat(latsFile)

        qTimes = [l/1e6 for l in latsObj.parseQueueTimes()]
        svcTimes = [l/1e6 for l in latsObj.parseSvcTimes()]
        sjrnTimes = [l/1e6 for l in latsObj.parseSojournTimes()]
        f = open('lats.txt','w')

        f.write('%12s | %12s | %12s\n\n' \
                % ('QueueTimes', 'ServiceTimes', 'SojournTimes'))

        for (q, svc, sjrn) in zip(qTimes, svcTimes, sjrnTimes):
            f.write("%12s | %12s | %12s\n" \
                    % ('%.3f' % q, '%.3f' % svc, '%.3f' % sjrn))
        f.close()

        percentiles = [50, 75, 90, 95, 99, 99.5]

        for percentile in percentiles:
            percentile_value = stats.scoreatpercentile(qTimes, percentile)
            print("[Queue] " + str(percentile) + "th percentile latency %.3f ms" \
                    % (percentile_value))
        print("[Queue] Mean overall latency %.3f ms" % (np.mean(qTimes)))
        print("[Queue] Max overall latency %.3f ms\n" % (max(qTimes)))

        for percentile in percentiles:
            percentile_value = stats.scoreatpercentile(svcTimes, percentile)
            print("[Service] " + str(percentile) + "th percentile latency %.3f ms" \
                    % (percentile_value))
        print("[Service] Mean overall latency %.3f ms" % (np.mean(svcTimes)))
        print("[Service] Max overall latency %.3f ms\n" % (max(svcTimes)))

        for percentile in percentiles:
            percentile_value = stats.scoreatpercentile(sjrnTimes, percentile)
            print("[Sojourn] " + str(percentile) + "th percentile latency %.3f ms" \
                    % (percentile_value))
        print("[Sojourn] Mean overall latency %.3f ms" % (np.mean(sjrnTimes)))
        print("[Sojourn] Max overall latency %.3f ms" % (max(sjrnTimes)))

        """
        draw_pdf(svcTimes, 1000)
        savefig("svcTimes.png")
        draw_pdf(sjrnTimes, 1000)
        savefig("sjrnTimes.png")
        """

    latsFile = sys.argv[1]
    getLatPct(latsFile)

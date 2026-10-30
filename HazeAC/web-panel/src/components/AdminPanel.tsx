import React, { useState, useEffect } from 'react';
import { fetchNui, sendNui } from '../utils/fetchNui';

interface Player {
  id: number;
  name: string;
  license: string;
  license2: string;
  steam: string;
  discord: string;
  hwid: string;
  strikes: Record<string, number>;
  connected: boolean;
}

interface Ban {
  name: string;
  license: string;
  license2: string;
  hwid: string;
  reason: string;
  bannedAt: number;
  expiresAt: number;
  permanent: boolean;
}

interface AnticheatStats {
  players: number;
  monitored: number;
  activeStrikes: number;
  totalBans: number;
  punishAction: string;
  punishDuration: number;
}

const AdminPanel: React.FC = () => {
  const [players, setPlayers] = useState<Player[]>([]);
  const [bans, setBans] = useState<Ban[]>([]);
  const [stats, setStats] = useState<AnticheatStats | null>(null);
  const [activeTab, setActiveTab] = useState<'players' | 'bans' | 'stats'>('stats');
  const [selectedPlayer, setSelectedPlayer] = useState<Player | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadData();
    const interval = setInterval(loadData, 5000);
    return () => clearInterval(interval);
  }, []);

  // Listen for openPanel message from server
  useEffect(() => {
    const handleMessage = (event: MessageEvent) => {
      const data = event.data;
      if (data.action === 'openPanel') {
        loadData();
      }
    };

    window.addEventListener('message', handleMessage);
    return () => window.removeEventListener('message', handleMessage);
  }, []);

  const closePanel = () => {
    sendNui('closePanel');
  };

  const loadData = async () => {
    try {
      const [playersData, bansData, statsData] = await Promise.all([
        fetchNui<Player[]>('getPlayers'),
        fetchNui<Ban[]>('getBans'),
        fetchNui<AnticheatStats>('getStats')
      ]);
      setPlayers(playersData);
      setBans(bansData);
      setStats(statsData);
    } catch (error) {
      console.error('Failed to load data:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleBanPlayer = async (player: Player, reason: string, duration: number) => {
    try {
      await fetchNui('banPlayer', { playerId: player.id, reason, duration });
      await loadData();
    } catch (error) {
      console.error('Failed to ban player:', error);
    }
  };

  const handleUnban = async (ban: Ban) => {
    try {
      await fetchNui('unban', { license: ban.license });
      await loadData();
    } catch (error) {
      console.error('Failed to unban:', error);
    }
  };

  const handleResetStrikes = async (player: Player) => {
    try {
      await fetchNui('resetStrikes', { playerId: player.id });
      await loadData();
    } catch (error) {
      console.error('Failed to reset strikes:', error);
    }
  };

  const formatDate = (timestamp: number): string => {
    if (timestamp === 0) return 'Permanent';
    return new Date(timestamp * 1000).toLocaleString();
  };

  const getStrikeCount = (player: Player): number => {
    return Object.values(player.strikes).reduce((sum, count) => sum + count, 0);
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-gray-900 text-white">
        <div className="text-xl">Loading...</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white p-6">
      <div className="max-w-7xl mx-auto">
        <div className="flex justify-between items-center mb-6">
          <h1 className="text-3xl font-bold">HazeAC Admin Panel</h1>
          <button
            onClick={closePanel}
            className="bg-red-600 hover:bg-red-700 px-4 py-2 rounded"
          >
            Close Panel
          </button>
        </div>

        {/* Tabs */}
        <div className="flex space-x-4 mb-6 border-b border-gray-700">
          <button
            onClick={() => setActiveTab('stats')}
            className={`px-4 py-2 ${activeTab === 'stats' ? 'border-b-2 border-blue-500 text-blue-400' : 'text-gray-400'}`}
          >
            Statistics
          </button>
          <button
            onClick={() => setActiveTab('players')}
            className={`px-4 py-2 ${activeTab === 'players' ? 'border-b-2 border-blue-500 text-blue-400' : 'text-gray-400'}`}
          >
            Players
          </button>
          <button
            onClick={() => setActiveTab('bans')}
            className={`px-4 py-2 ${activeTab === 'bans' ? 'border-b-2 border-blue-500 text-blue-400' : 'text-gray-400'}`}
          >
            Bans
          </button>
        </div>

        {/* Stats Tab */}
        {activeTab === 'stats' && stats && (
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="bg-gray-800 p-4 rounded-lg">
              <h3 className="text-lg font-semibold mb-2">Online Players</h3>
              <p className="text-3xl font-bold text-blue-400">{stats.players}</p>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <h3 className="text-lg font-semibold mb-2">Monitored</h3>
              <p className="text-3xl font-bold text-green-400">{stats.monitored}</p>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <h3 className="text-lg font-semibold mb-2">Active Strikes</h3>
              <p className="text-3xl font-bold text-yellow-400">{stats.activeStrikes}</p>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <h3 className="text-lg font-semibold mb-2">Total Bans</h3>
              <p className="text-3xl font-bold text-red-400">{stats.totalBans}</p>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <h3 className="text-lg font-semibold mb-2">Punish Action</h3>
              <p className="text-xl font-bold text-purple-400">{stats.punishAction}</p>
            </div>
            <div className="bg-gray-800 p-4 rounded-lg">
              <h3 className="text-lg font-semibold mb-2">Ban Duration</h3>
              <p className="text-xl font-bold text-purple-400">
                {stats.punishDuration === 0 ? 'Permanent' : `${stats.punishDuration}s`}
              </p>
            </div>
          </div>
        )}

        {/* Players Tab */}
        {activeTab === 'players' && (
          <div className="bg-gray-800 rounded-lg overflow-hidden">
            <table className="w-full">
              <thead className="bg-gray-700">
                <tr>
                  <th className="px-4 py-3 text-left">ID</th>
                  <th className="px-4 py-3 text-left">Name</th>
                  <th className="px-4 py-3 text-left">License</th>
                  <th className="px-4 py-3 text-left">Strikes</th>
                  <th className="px-4 py-3 text-left">HWID</th>
                  <th className="px-4 py-3 text-left">Actions</th>
                </tr>
              </thead>
              <tbody>
                {players.map((player) => (
                  <tr key={player.id} className="border-b border-gray-700 hover:bg-gray-700">
                    <td className="px-4 py-3">{player.id}</td>
                    <td className="px-4 py-3">{player.name}</td>
                    <td className="px-4 py-3 text-xs">{player.license.substring(0, 20)}...</td>
                    <td className="px-4 py-3">
                      <span className={`px-2 py-1 rounded ${
                        getStrikeCount(player) > 0 ? 'bg-yellow-600' : 'bg-green-600'
                      }`}>
                        {getStrikeCount(player)}
                      </span>
                    </td>
                    <td className="px-4 py-3 text-xs">{player.hwid}</td>
                    <td className="px-4 py-3">
                      <button
                        onClick={() => setSelectedPlayer(player)}
                        className="bg-blue-600 hover:bg-blue-700 px-3 py-1 rounded mr-2"
                      >
                        Manage
                      </button>
                      <button
                        onClick={() => handleResetStrikes(player)}
                        className="bg-gray-600 hover:bg-gray-700 px-3 py-1 rounded"
                      >
                        Reset
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Bans Tab */}
        {activeTab === 'bans' && (
          <div className="bg-gray-800 rounded-lg overflow-hidden">
            <table className="w-full">
              <thead className="bg-gray-700">
                <tr>
                  <th className="px-4 py-3 text-left">Name</th>
                  <th className="px-4 py-3 text-left">Reason</th>
                  <th className="px-4 py-3 text-left">HWID</th>
                  <th className="px-4 py-3 text-left">Banned At</th>
                  <th className="px-4 py-3 text-left">Expires</th>
                  <th className="px-4 py-3 text-left">Actions</th>
                </tr>
              </thead>
              <tbody>
                {bans.map((ban, index) => (
                  <tr key={index} className="border-b border-gray-700 hover:bg-gray-700">
                    <td className="px-4 py-3">{ban.name}</td>
                    <td className="px-4 py-3">{ban.reason}</td>
                    <td className="px-4 py-3 text-xs">{ban.hwid}</td>
                    <td className="px-4 py-3">{formatDate(ban.bannedAt)}</td>
                    <td className="px-4 py-3">{formatDate(ban.expiresAt)}</td>
                    <td className="px-4 py-3">
                      <button
                        onClick={() => handleUnban(ban)}
                        className="bg-red-600 hover:bg-red-700 px-3 py-1 rounded"
                      >
                        Unban
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {/* Player Management Modal */}
        {selectedPlayer && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center">
            <div className="bg-gray-800 p-6 rounded-lg max-w-md w-full">
              <h2 className="text-2xl font-bold mb-4">Manage Player: {selectedPlayer.name}</h2>
              
              <div className="mb-4">
                <h3 className="font-semibold mb-2">Strikes by Type:</h3>
                {Object.entries(selectedPlayer.strikes).map(([type, count]) => (
                  <div key={type} className="flex justify-between">
                    <span>{type}</span>
                    <span className="font-bold">{count}</span>
                  </div>
                ))}
              </div>

              <div className="mb-4">
                <label className="block mb-2">Ban Reason:</label>
                <input
                  type="text"
                  id="banReason"
                  className="w-full bg-gray-700 rounded px-3 py-2"
                  placeholder="Enter reason..."
                />
              </div>

              <div className="mb-4">
                <label className="block mb-2">Duration (seconds, 0 = permanent):</label>
                <input
                  type="number"
                  id="banDuration"
                  className="w-full bg-gray-700 rounded px-3 py-2"
                  defaultValue="0"
                />
              </div>

              <div className="flex space-x-4">
                <button
                  onClick={() => {
                    const reason = (document.getElementById('banReason') as HTMLInputElement).value;
                    const duration = parseInt((document.getElementById('banDuration') as HTMLInputElement).value);
                    handleBanPlayer(selectedPlayer, reason, duration);
                    setSelectedPlayer(null);
                  }}
                  className="bg-red-600 hover:bg-red-700 px-4 py-2 rounded flex-1"
                >
                  Ban Player
                </button>
                <button
                  onClick={() => setSelectedPlayer(null)}
                  className="bg-gray-600 hover:bg-gray-700 px-4 py-2 rounded flex-1"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default AdminPanel;

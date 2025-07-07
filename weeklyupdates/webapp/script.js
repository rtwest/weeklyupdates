// Modern PigeonNotes App with Personality
let updates = [];
let isEditing = false;
let editingIndex = -1;
let autoSummaryEnabled = true;
let autoSummaryInterval = null;

// Initialize the app
document.addEventListener('DOMContentLoaded', function() {
    console.log('🐦 PigeonNotes app initialized');
    loadUpdates();
    loadSettings();
    setupEventListeners();
    updateEmptyState();
    setupAutoSummary();
});

// Set up event listeners
function setupEventListeners() {
    const addBtn = document.getElementById('addNoteBtn');
    const noteContent = document.getElementById('noteContent');
    const settingsBtn = document.getElementById('settingsBtn');
    const closeBtn = document.getElementById('closeBtn');
    const generateSummaryBtn = document.getElementById('generateSummaryBtn');
    
    addBtn.addEventListener('click', addUpdate);
    noteContent.addEventListener('keydown', handleKeyPress);
    settingsBtn.addEventListener('click', openSettings);
    closeBtn.addEventListener('click', closeApp);
    generateSummaryBtn.addEventListener('click', generateSummary);
    
    // Settings modal
    document.getElementById('saveSettings').addEventListener('click', saveSettings);
    document.getElementById('cancelSettings').addEventListener('click', closeSettings);
    document.getElementById('resetPromptBtn').addEventListener('click', resetPrompt);
    
    // Confirmation modal
    document.getElementById('confirmYes').addEventListener('click', function() {
        console.log('User confirmed deletion');
        document.getElementById('confirmModal').style.display = 'none';
    });
    document.getElementById('confirmNo').addEventListener('click', function() {
        console.log('User cancelled deletion');
        document.getElementById('confirmModal').style.display = 'none';
    });
    
    // Load saved settings
    loadSettings();
    
    // Initialize auto-summary checkbox state
    const autoSummaryCheckbox = document.getElementById('autoSummaryCheckbox');
    if (autoSummaryCheckbox) {
        autoSummaryCheckbox.checked = autoSummaryEnabled;
    }
}

// Handle keyboard shortcuts
function handleKeyPress(e) {
    if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        addUpdate();
    }
}

// Add a new update
function addUpdate() {
    const content = document.getElementById('noteContent').value.trim();
    
    if (!content) {
        console.log('📝 No content to add');
        return;
    }
    
    if (isEditing) {
        // Update existing note
        updates[editingIndex].content = content;
        updates[editingIndex].updatedAt = new Date().toISOString();
        console.log('✏️ Updated existing update');
    } else {
        // Add new note
        const newUpdate = {
            content: content,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };
        updates.unshift(newUpdate);
        console.log('✨ Added new update');
    }
    
    // Clear form and reset state
    document.getElementById('noteContent').value = '';
    isEditing = false;
    editingIndex = -1;
    
    // Update UI
    displayUpdates();
    saveUpdates();
    updateEmptyState();
    
    // Update button text
    document.getElementById('addNoteBtn').textContent = 'Add Update';
    
    // Focus back to textarea
    document.getElementById('noteContent').focus();
}

// Display all updates
function displayUpdates() {
    const container = document.getElementById('updatesContainer');
    
    if (updates.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <h3>Ready to capture your week? 📝</h3>
                <p>Start by adding your first update above. Every journey begins with a single step!</p>
            </div>
        `;
        return;
    }
    
    container.innerHTML = updates.map((update, index) => {
        const date = new Date(update.createdAt);
        const formattedDate = date.toLocaleDateString('en-US', { 
            month: 'short', 
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
        
        return `
            <div class="update-item" data-index="${index}">
                <div class="update-meta">
                    <span class="update-date">📅 ${formattedDate}</span>
                </div>
                <div class="update-content">${update.content}</div>
                <div class="update-actions">
                    <button class="edit-btn" onclick="editUpdate(${index})" title="Edit this update">✏️ Edit</button>
                    <button class="delete-btn" onclick="deleteUpdate(${index})" title="Delete this update">🗑️ Delete</button>
                </div>
            </div>
        `;
    }).join('');
}

// Edit an update
function editUpdate(index) {
    console.log('✏️ Editing update at index:', index);
    
    const update = updates[index];
    document.getElementById('noteContent').value = update.content;
    document.getElementById('noteContent').focus();
    
    isEditing = true;
    editingIndex = index;
    
    // Update button text
    document.getElementById('addNoteBtn').textContent = 'Update';
    
    // Scroll to top
    window.scrollTo(0, 0);
}

// Delete an update
function deleteUpdate(index) {
    console.log('🗑️ Deleting update at index:', index);
    
    if (index < 0 || index >= updates.length) {
        console.error('Invalid index for deletion:', index);
        return;
    }
    
    const updateToDelete = updates[index];
    const message = `Are you sure you want to delete this update?<br><br><div class="note-preview">"${updateToDelete.content.substring(0, 100)}${updateToDelete.content.length > 100 ? '...' : ''}"</div><br>This action cannot be undone.`;
    
    showConfirmModal(message, 
        // onConfirm callback
        () => {
            console.log('✅ User confirmed deletion - proceeding with delete');
            
            // Remove from local array
            updates.splice(index, 1);
            console.log('🗑️ Update removed from local array');
            
            // Update UI
            displayUpdates();
            console.log('🎨 UI updated after delete');
            
            // Save to native app
            saveUpdates();
            console.log('💾 Changes saved to native app');
            
            updateEmptyState();
        },
        // onCancel callback
        () => {
            console.log('❌ User cancelled deletion - update kept');
        }
    );
}

// Show confirmation modal
function showConfirmModal(message, onConfirm, onCancel) {
    console.log('🤔 Showing confirmation modal');
    
    const confirmModal = document.getElementById('confirmModal');
    const confirmMessage = document.getElementById('confirmMessage');
    const confirmYesBtn = document.getElementById('confirmYes');
    const confirmNoBtn = document.getElementById('confirmNo');
    
    // Set the message
    confirmMessage.innerHTML = message;
    
    // Show the modal
    confirmModal.style.display = 'block';
    
    // Set up event listeners
    const handleConfirm = () => {
        console.log('✅ User confirmed in modal');
        confirmModal.style.display = 'none';
        confirmYesBtn.removeEventListener('click', handleConfirm);
        confirmNoBtn.removeEventListener('click', handleCancel);
        if (onConfirm) onConfirm();
    };
    
    const handleCancel = () => {
        console.log('❌ User cancelled in modal');
        confirmModal.style.display = 'none';
        confirmYesBtn.removeEventListener('click', handleConfirm);
        confirmNoBtn.removeEventListener('click', handleCancel);
        if (onCancel) onCancel();
    };
    
    confirmYesBtn.addEventListener('click', handleConfirm);
    confirmNoBtn.addEventListener('click', handleCancel);
    
    // Close modal when clicking outside
    confirmModal.addEventListener('click', function(e) {
        if (e.target === confirmModal) {
            handleCancel();
        }
    });
}

// Update empty state
function updateEmptyState() {
    const container = document.getElementById('updatesContainer');
    if (updates.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <h3>Ready to capture your week? 📝</h3>
                <p>Start by adding your first update above. Every journey begins with a single step!</p>
            </div>
        `;
    }
}

// Load updates from native app
function loadUpdates() {
    console.log('📥 Loading updates from native app...');
    
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.loadUpdates) {
        window.webkit.messageHandlers.loadUpdates.postMessage({});
    } else {
        console.log('🌐 Running in browser - loading from localStorage');
        const saved = localStorage.getItem('weeklyUpdates');
        if (saved) {
            updates = JSON.parse(saved);
            displayUpdates();
        }
    }
}

// Save updates to native app
function saveUpdates() {
    console.log('💾 Saving updates to native app...');
    
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.saveUpdates) {
        window.webkit.messageHandlers.saveUpdates.postMessage({ updates: updates });
    } else {
        console.log('🌐 Running in browser - saving to localStorage');
        localStorage.setItem('weeklyUpdates', JSON.stringify(updates));
    }
}

// Open settings modal
function openSettings() {
    console.log('⚙️ Opening settings modal');
    document.getElementById('settingsModal').style.display = 'block';
}

// Close settings modal
function closeSettings() {
    console.log('❌ Closing settings modal');
    document.getElementById('settingsModal').style.display = 'none';
}

// Save settings
function saveSettings() {
    console.log('💾 Saving settings...');
    
    const apiKey = document.getElementById('openaiKey').value;
    const prompt = document.getElementById('summaryPrompt').value;
    const autoSummary = document.getElementById('autoSummaryCheckbox').checked;
    
    localStorage.setItem('openaiApiKey', apiKey);
    localStorage.setItem('summaryPrompt', prompt);
    localStorage.setItem('autoSummaryEnabled', autoSummary.toString());
    
    // Update the global variable
    autoSummaryEnabled = autoSummary;
    
    closeSettings();
    console.log('✅ Settings saved successfully');
}

// Load settings
function loadSettings() {
    console.log('📥 Loading settings...');
    
    const apiKey = localStorage.getItem('openaiApiKey') || '';
    const prompt = localStorage.getItem('summaryPrompt') || getDefaultPrompt();
    const autoSummary = localStorage.getItem('autoSummaryEnabled');
    
    // Set auto-summary setting (default to true)
    autoSummaryEnabled = autoSummary === null ? true : autoSummary === 'true';
    
    document.getElementById('openaiKey').value = apiKey;
    document.getElementById('summaryPrompt').value = prompt;
    
    // Set checkbox state
    const autoSummaryCheckbox = document.getElementById('autoSummaryCheckbox');
    if (autoSummaryCheckbox) {
        autoSummaryCheckbox.checked = autoSummaryEnabled;
    }
}

// Reset prompt to default
function resetPrompt() {
    console.log('🔄 Resetting prompt to default');
    document.getElementById('summaryPrompt').value = getDefaultPrompt();
}

// Get default prompt
function getDefaultPrompt() {
    return `Create a concise summary of these weekly updates for a UX. This summary will be shared as a weekly team Slack message that highlights key information for the team. Keep the tone fun and light. Be encouraging and actionable.`;
}

// Generate AI summary
function generateSummary() {
    console.log('🤖 Generating AI summary...');
    
    if (updates.length === 0) {
        console.log('📝 No updates to summarize');
        return;
    }
    
    const apiKey = localStorage.getItem('openaiApiKey');
    if (!apiKey) {
        console.log('🔑 No API key found');
        alert('Please add your OpenAI API key in settings first! 🔑');
        openSettings();
        return;
    }
    
    const prompt = localStorage.getItem('summaryPrompt') || getDefaultPrompt();
    const updatesText = updates.map(update => update.content).join('\n\n');
    
    const generateBtn = document.getElementById('generateSummaryBtn');
    const originalText = generateBtn.textContent;
    generateBtn.textContent = '🤖 Generating...';
    generateBtn.disabled = true;
    
    // Call native app to generate summary
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.generateSummary) {
        window.webkit.messageHandlers.generateSummary.postMessage({
            apiKey: apiKey,
            prompt: prompt,
            updates: updatesText
        });
    } else {
        console.log('🌐 Running in browser - would call OpenAI API here');
        // Simulate API call for browser testing
        setTimeout(() => {
            const summary = "This is a simulated AI summary for browser testing. In the actual app, this would be generated by OpenAI's GPT model based on your weekly updates.";
            displaySummary(summary);
            generateBtn.textContent = originalText;
            generateBtn.disabled = false;
        }, 2000);
    }
}

// Display summary
function displaySummary(summary) {
    console.log('📊 Displaying summary');
    
    const summaryDisplay = document.getElementById('summaryDisplay');
    const summaryContent = document.getElementById('summaryContent');
    
    summaryContent.innerHTML = summary.replace(/\n/g, '<br>');
    summaryDisplay.style.display = 'block';
    
    // Scroll to summary
    summaryDisplay.scrollIntoView({ behavior: 'smooth' });
}

// Close app
function closeApp() {
    console.log('👋 Closing app');
    
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.closeApp) {
        window.webkit.messageHandlers.closeApp.postMessage({});
    } else {
        console.log('🌐 Running in browser - would close app');
    }
}

// Handle messages from native app
function handleNativeMessage(message) {
    console.log('📨 Received message from native app:', message);
    
    if (message.type === 'updatesLoaded') {
        updates = message.updates || [];
        displayUpdates();
        updateEmptyState();
        console.log('✅ Updates loaded from native app');
    } else if (message.type === 'summaryGenerated') {
        displaySummary(message.summary);
        document.getElementById('generateSummaryBtn').textContent = '🤖 Generate AI Summary';
        document.getElementById('generateSummaryBtn').disabled = false;
        console.log('✅ Summary generated by native app');
    }
}

// Auto-summary functionality
function setupAutoSummary() {
    console.log('📅 Setting up auto-summary generation');
    
    // Check if it's Friday at 9am and auto-summary is enabled
    const now = new Date();
    const isFriday = now.getDay() === 5; // 5 = Friday
    const is9AM = now.getHours() === 9 && now.getMinutes() < 10; // Within 10 minutes of 9am
    
    if (isFriday && is9AM && autoSummaryEnabled && updates.length > 0) {
        console.log('🤖 Auto-generating weekly summary (Friday 9am)');
        generateSummary();
    }
    
    // Set up interval to check every hour
    autoSummaryInterval = setInterval(() => {
        const currentTime = new Date();
        const currentDay = currentTime.getDay();
        const currentHour = currentTime.getHours();
        const currentMinute = currentTime.getMinutes();
        
        // Check if it's Friday at 9am (within 10 minutes)
        if (currentDay === 5 && currentHour === 9 && currentMinute < 10 && autoSummaryEnabled && updates.length > 0) {
            console.log('🤖 Auto-generating weekly summary (Friday 9am)');
            generateSummary();
        }
    }, 60 * 60 * 1000); // Check every hour
}



function showNotification(message) {
    // Create a simple notification
    const notification = document.createElement('div');
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: var(--primary-color);
        color: white;
        padding: 12px 16px;
        border-radius: var(--radius-md);
        font-size: 14px;
        z-index: 10000;
        box-shadow: var(--shadow-md);
        animation: slideIn 0.3s ease;
    `;
    notification.textContent = message;
    
    // Add animation CSS
    const style = document.createElement('style');
    style.textContent = `
        @keyframes slideIn {
            from { transform: translateX(100%); opacity: 0; }
            to { transform: translateX(0); opacity: 1; }
        }
    `;
    document.head.appendChild(style);
    
    document.body.appendChild(notification);
    
    // Remove after 3 seconds
    setTimeout(() => {
        notification.remove();
        style.remove();
    }, 3000);
}

// Expose function to native app
window.handleNativeMessage = handleNativeMessage; 